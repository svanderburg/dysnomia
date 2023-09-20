{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableEjabberdDump = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  ejabberd_dump = import ./deployment/ejabberd-dump.nix {
    inherit stdenv;
  };
in
makeTest {
  name = "ejabberd-dump";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.ejabberd.enable = true;
      services.ejabberd.configFile = ./services/ejabberd-dump/ejabberd.yml;
      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_num_of_snapshot_generations(num):
          actual_num = machine.succeed(
              "ls /var/state/dysnomia/snapshots/ejabberd-dump/* | wc -l"
          )

          if int(num) != int(actual_num):
              raise Exception(
                  "Expecting {num} snapshot generations, but we have: {actual_num}".format(
                      num=num, actual_num=actual_num
                  )
              )


      start_all()

      machine.wait_for_unit("ejabberd")

      ejabberdSettings = "ejabberdUser=ejabberd"

      # Test ejabberd dump module. First we check if we can
      # login with an admin account (which is not the case), then
      # we activate the dump and we check the admin account again.
      # Now we should be able to login. This test should succeed.

      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation activate --component ${ejabberd_dump} --environment"
      )
      machine.succeed(
          "curl --fail --user 'admin@localhost:admin' http://localhost:5280/admin"
      )

      # Take a snapshot of the ejabberd database.
      # This test should succeed.
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Take another snapshot of the ejabberd database. Because nothing changed, no
      # new snapshot is supposed to be taken. This test should succeed.
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Make a modification (creating a new user) and take another snapshot.
      # Because something changed, a new snapshot is supposed to be taken. This
      # test should succeed.
      machine.succeed(
          'su ejabberd -s /bin/sh -c "ejabberdctl register newuser localhost newuser"'
      )

      machine.succeed(
          "curl --fail --user 'newuser@localhost:newuser' http://localhost:5280/admin"
      )
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment"
      )
      check_num_of_snapshot_generations(2)

      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation collect-garbage --component ${ejabberd_dump} --environment"
      )
      machine.succeed("[ -e /var/lib/ejabberd ]")

      # Deactivate the ejabberd database. This test should succeed.
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation deactivate --component ${ejabberd_dump} --environment"
      )

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation deactivate --component ${ejabberd_dump} --environment"
      )

      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      machine.succeed("systemctl stop ejabberd")
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation collect-garbage --component ${ejabberd_dump} --environment"
      )
      result = machine.succeed("ls -A /var/lib/ejabberd | wc -l")

      if int(result) == 0:
          print("There are no files left in the spool directory!")
      else:
          raise Exception("There are {} files left in the spool directory!".format(result))

      # Activate the ejabberd database again. This test should succeed.
      machine.succeed("systemctl start ejabberd")
      machine.wait_for_unit("ejabberd")
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation activate --component ${ejabberd_dump} --environment"
      )
      machine.fail(
          "curl --fail --user 'newuser@localhost:newuser' http://localhost:5280/admin"
      )

      # Restore the last snapshot and check whether it contains the recently
      # added user. This test should succeed.
      machine.succeed("sleep 3")
      machine.succeed(
          ejabberdSettings
          + " dysnomia --type ejabberd-dump --operation restore --component ${ejabberd_dump} --environment"
      )
      # machine.succeed(
      #      "curl --fail --user 'newuser@localhost:newuser' http://localhost:5280/admin"
      # )
    '';
}
