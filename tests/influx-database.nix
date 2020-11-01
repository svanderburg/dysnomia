{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableInfluxDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services
  influx_database = import ./deployment/influx-database.nix {
    inherit stdenv;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.influxdb = {
        enable = true;
      };

      environment.systemPackages = [ dysnomia pkgs.influxdb ];
    };
  };

  testScript =
    ''
      def check_num_of_snapshot_generations(num):
          actual_num = machine.succeed(
              "ls /var/state/dysnomia/snapshots/influx-database/* | wc -l"
          )

          if int(num) != int(actual_num):
              raise Exception(
                  "Expecting {num} snapshot generations, but we have: {actual_num}".format(
                      num=num, actual_num=actual_num
                  )
              )


      start_all()

      machine.wait_for_unit("influxdb")

      influxdbCredentials = "influxdbUsername=influxdb"

      # Test InfluxDB module. Here we activate a database
      # and we check whether it is created. This test should succeed.

      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation activate --component ${influx_database} --environment"
      )
      result = machine.succeed(
          "su influxdb -s /bin/sh -c \"influx -database testdb -execute 'select * from cpu'\""
      )

      if "serverA" in result:
          print("InfluxDB query returns: serverA!")
      else:
          raise Exception("InfluxDB cpu measurements should contain: serverA!")

      # Activate the database again. It should proceed without doing anything.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation activate --component ${influx_database} --environment"
      )

      # Take a snapshot of the InfluxDB database.
      # This test should succeed.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation snapshot --component ${influx_database} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      machine.succeed(
          "influx -database testdb -execute 'INSERT cpu,host=serverB,region=us_west value=0.54'"
      )
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation snapshot --component ${influx_database} --environment"
      )
      check_num_of_snapshot_generations(2)

      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation collect-garbage --component ${influx_database} --environment"
      )
      machine.succeed("influx -database testdb -execute 'select * from cpu'")

      # Deactivate the InfluxDB database again. This test should succeed.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation deactivate --component ${influx_database} --environment"
      )

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation deactivate --component ${influx_database} --environment"
      )

      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation collect-garbage --component ${influx_database} --environment"
      )
      machine.fail("influx -database testdb -execute 'select * from cpu'")

      # Activate the InfluxDB database again. This test should succeed.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation activate --component ${influx_database} --environment"
      )

      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      machine.succeed(
          influxdbCredentials
          + " dysnomia --type influx-database --operation restore --component ${influx_database} --environment"
      )
      result = machine.succeed(
          "sleep 10; influx -database testdb -execute 'select * from cpu'"
      )

      if "serverB" in result:
          print("InfluxDB query returns: serverB!")
      else:
          raise Exception("InfluxDB cpu measurements should contain: serverB!")
    '';
}
