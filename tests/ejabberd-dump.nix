{ nixpkgs, buildFun }:

let
  dysnomia = buildFun {
    system = builtins.currentSystem;
    enableEjabberdDump = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  # Test services
  
  ejabberd_dump = import ./deployment/ejabberd-dump.nix {
    inherit stdenv;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:
      
    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;
        
      services.ejabberd.enable = true;

      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      startAll;
      
      # Test ejabberd dump activation script. First we check if we can
      # login with an admin account (which is not the case), then
      # we activate the dump and we check the admin account again.
      # Now we should be able to login. This test should succeed.
        
      $machine->waitForJob("ejabberd");
      $machine->mustFail("curl --fail --user admin:admin http://localhost:5280/admin");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation activate --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("curl --fail --user admin:admin http://localhost:5280/admin");
      
      # Take a snapshot of the ejabberd database.
      # This test should succeed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/ejabberd-dump/* | wc -l)\" = \"1\" ]");
      
      # Take another snapshot of the ejabberd database. Because nothing changed, no
      # new snapshot is supposed to be taken. This test should succeed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/ejabberd-dump/* | wc -l)\" = \"1\" ]");
      
      # Make a modification (creating a new user) and take another snapshot.
      # Because something changed, a new snapshot is supposed to be taken. This
      # test should succeed.
      $machine->mustSucceed("su ejabberd -s /bin/sh -c \"ejabberdctl register newuser localhost newuser\"");
      $machine->mustSucceed("curl --fail --user newuser:newuser http://localhost:5280/admin");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/ejabberd-dump/* | wc -l)\" = \"2\" ]");
      
      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation collect-garbage --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ -e /var/lib/ejabberd ]");
      
      # Deactivate the ejabberd database. This test should succeed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation deactivate --component ${ejabberd_dump} --environment");
      
      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("systemctl stop ejabberd");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation collect-garbage --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ ! -e /var/lib/ejabberd ]");
      
      # Activate the ejabberd database again. This test should succeed.
      $machine->mustSucceed("systemctl start ejabberd");
      $machine->waitForJob("ejabberd");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation activate --component ${ejabberd_dump} --environment");
      $machine->mustFail("curl --fail --user newuser:newuser http://localhost:5280/admin");
      
      # Restore the last snapshot and check whether it contains the recently
      # added user. This test should succeed.
      $machine->mustSucceed("sleep 3; ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation restore --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("curl --fail --user newuser:newuser http://localhost:5280/admin");
    '';
}
