{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

makeTest {
  nodes = {
    machine = {config, pkgs, ...}:
      
    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;
    
      imports = [ ../dysnomia-module.nix ];
      
      services.dysnomia = {
        enable = true;
        
        components = {
          mysql-database = {
            testdb = import ./deployment/mysql-database.nix {
              inherit (pkgs) stdenv;
            };
          };
          
          postgresql-database = {
            testdb = import ./deployment/postgresql-database.nix {
              inherit (pkgs) stdenv;
            };
          };
        };
      };
    
      services.mysql = {
        enable = true;
        package = pkgs.mysql;
        rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
      };
      
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql;
      };
    
      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      startAll;
      
      $machine->waitForJob("mysql");
      $machine->waitForJob("postgresql");
      
      # Test NixOS configuration activation script. We activate the current
      # NixOS configuration
      $machine->mustSucceed("disableNixOSSystemProfile=1 testNixOS=1 DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia --type nixos-configuration --operation activate --component /var/run/current-system --environment");
      
      # Deploy the mutable components
      # TODO: maybe integrate this as part of the activation script
      $machine->mustSucceed("DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos dysnomia-containers --deploy");
      
      # Snapshot the NixOS configuration's state
      $machine->mustSucceed("disableNixOSSystemProfile=1 testNixOS=1 DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia --type nixos-configuration --operation snapshot --component /var/run/current-system --environment");
      
      # When querying the snapshots of the NixOS state directory, we should get a
      # MySQL and PostgreSQL snapshot
      my $result = $machine->mustSucceed("DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos dysnomia-snapshots --query-all");
      my @snapshots = split('\n', $result);
      
      if(scalar(grep(/mysql-database\/testdb/, @snapshots)) == 1) {
          print "mysql-database/testdb is in the snapshots query!\n";
      } else {
          die "mysql-database/testdb is in the snapshots query!";
      }
      
      if(scalar(grep(/postgresql-database\/testdb/, @snapshots)) == 1) {
          print "postgresql-database/testdb is in the snapshots query!\n";
      } else {
          die "postgresql-database/testdb is in the snapshots query!";
      }
      
      # When querying the snapshots of the "regular" statedir, we should get one
      # snapshot. Its contents consists of a MySQL and PostgreSQL database
      # snapshot.
      
      $result = $machine->mustSucceed("DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia-snapshots --query-all");
      @snapshots = split('\n', $result);
      
      if(scalar(@snapshots) == 1) {
          print "We have 1 regular snapshot!\n";
      } else {
          die "We should have 1 regular snapshot!";
      }
      
      $result = $machine->mustSucceed("DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia-snapshots --resolve $result");
      $result = $machine->mustSucceed("find ".(substr $result, 0, -1)." -maxdepth 2 -mindepth 2 | wc -l");
      
      if($result == 2) {
          print "We have 2 snapshots in the nixos-configuration composite!\n";
      } else {
          die "We should have 2 snapshots in the nixos-configuration composite!";
      }
      
      # Modify the state of the databases
      
      $machine->mustSucceed("echo \"insert into test values ('Bye world');\" | mysql --user=root --password=verysecret -N testdb");
      $machine->mustSucceed("echo \"insert into test values ('Bye world');\" | psql --file - testdb");
      
      # Drop all the snapshots part of the NixOS state directory. They should be
      # restored from the NixOS configuration component.
      
      $machine->mustSucceed("DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos dysnomia-snapshots --gc --keep 0");
      
      # Restore the NixOS configuration's state and check whether the
      # modifications are gone.
      
      $machine->mustSucceed("disableNixOSSystemProfile=1 testNixOS=1 DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia --type nixos-configuration --operation restore --component /var/run/current-system --environment");
      
      $result = $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
      
      if($result =~ /Bye world/) {
          die "MySQL table should not contain: Bye world!\n";
      } else {
          print "MySQL does not contain: Bye world!\n";
      }
      
      $result = $machine->mustSucceed("echo 'select * from test' | psql --file - testdb");
      
      if($result =~ /Bye world/) {
          die "PostgreSQL table should not contain: Bye world!\n";
      } else {
          print "PostgreSQL does not contain: Bye world!\n";
      }
    '';
}
