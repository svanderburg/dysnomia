{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

makeTest {
  name = "nixos-configuration";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      imports = [ ../dysnomia-module.nix ];

      dysnomiaTest = {
        enable = true;
        enableAuthentication = true;

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

      services = {
        mysql = {
          enable = true;
          package = pkgs.mariadb;
        };

        postgresql = {
          enable = true;
          package = pkgs.postgresql;
        };
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      start_all()

      machine.wait_for_unit("mysql")
      machine.wait_for_unit("postgresql")

      # Test NixOS configuration module. We activate the current
      # NixOS configuration
      machine.succeed(
          "disableNixOSSystemProfile=1 testNixOS=1 DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia --type nixos-configuration --operation activate --component /var/run/current-system --environment"
      )

      # Snapshot the NixOS configuration's state
      machine.succeed(
          "disableNixOSSystemProfile=1 testNixOS=1 DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia --type nixos-configuration --operation snapshot --component /var/run/current-system --environment"
      )

      # When querying the snapshots of the NixOS state directory, we should get a
      # MySQL and PostgreSQL snapshot
      result = machine.succeed(
          "DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos dysnomia-snapshots --query-all"
      )
      snapshots = result.split("\n")

      if any("mysql-database/testdb" in s for s in snapshots):
          print("mysql-database/testdb is in the snapshots query!")
      else:
          raise Exception("mysql-database/testdb is not in the snapshots query!")

      if any("postgresql-database/testdb" in s for s in snapshots):
          print("postgresql-database/testdb is in the snapshots query!")
      else:
          raise Exception("postgresql-database/testdb is not in the snapshots query!")

      # When querying the snapshots of the "regular" statedir, we should get one
      # snapshot. Its contents consists of a MySQL and PostgreSQL database
      # snapshot.

      result = machine.succeed(
          "DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia-snapshots --query-all"
      )
      snapshots = list(filter(lambda s: s != "", result.split("\n")))

      if len(snapshots) == 1:
          print("We have 1 regular snapshot!")
      else:
          raise Exception(
              "We should have 1 regular snapshot, instead we have: {}!".format(len(snapshots))
          )

      result = machine.succeed(
          "DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia-snapshots --resolve {}".format(
              result
          )
      )
      result = machine.succeed("find {} -maxdepth 2 -mindepth 2 | wc -l".format(result[:-1]))

      if int(result) == 2:
          print("We have 2 snapshots in the nixos-configuration composite!")
      else:
          raise Exception("We should have 2 snapshots in the nixos-configuration composite!")

      # Modify the state of the databases

      machine.succeed("echo \"insert into test values ('Bye world');\" | mysql -N testdb")
      machine.succeed(
          "echo \"insert into test values ('Bye world');\" | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      # Drop all the snapshots part of the NixOS state directory. They should be
      # restored from the NixOS configuration component.
      machine.succeed(
          "DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos dysnomia-snapshots --gc --keep 0"
      )

      # Restore the NixOS configuration's state and check whether the
      # modifications are gone.

      machine.succeed(
          "disableNixOSSystemProfile=1 testNixOS=1 DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia --type nixos-configuration --operation restore --component /var/run/current-system --environment"
      )

      result = machine.succeed("echo 'select * from test' | mysql -N testdb")

      if "Bye world" in result:
          raise Exception("MySQL table should not contain: Bye world!")
      else:
          print("MySQL does not contain: Bye world!")

      result = machine.succeed(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      if "Bye world" in result:
          raise Exception("PostgreSQL table should not contain: Bye world!")
      else:
          print("PostgreSQL does not contain: Bye world!")
    '';
}
