{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableInfluxDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

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
      startAll;

      # Test InfluxDB module. Here we activate a database
      # and we check whether it is created. This test should succeed.

      $machine->waitForJob("influxdb");
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation activate --component ${influx_database} --environment");
      my $result = $machine->mustSucceed("su influxdb -s /bin/sh -c \"influx -database testdb -execute 'select * from cpu'\"");

      if($result =~ /serverA/) {
          print "InfluxDB query returns: serverA!\n";
      } else {
          die "InfluxDB cpu measurements should contain: serverA!\n";
      }

      # Activate the database again. It should proceed without doing anything.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation activate --component ${influx_database} --environment");

      # Take a snapshot of the InfluxDB database.
      # This test should succeed.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation snapshot --component ${influx_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/influx-database/* | wc -l)\" = \"1\" ]");

      # Take another snapshot of the InfluxDB database. Because nothing
      # changed, no new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation snapshot --component ${influx_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/influx-database/* | wc -l)\" = \"1\" ]");

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("influx -database testdb -execute 'INSERT cpu,host=serverB,region=us_west value=0.54'");
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation snapshot --component ${influx_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/influx-database/* | wc -l)\" = \"2\" ]");

      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation collect-garbage --component ${influx_database} --environment");
      $machine->mustSucceed("influx -database testdb -execute 'select * from cpu'");

      # Deactivate the InfluxDB database again. This test should succeed.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation deactivate --component ${influx_database} --environment");

      # Deactivate again. This test should succeed as the operation is idempotent.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation deactivate --component ${influx_database} --environment");

      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation collect-garbage --component ${influx_database} --environment");
      $machine->mustFail("influx -database testdb -execute 'select * from cpu'");

      # Activate the InfluxDB database again. This test should succeed.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation activate --component ${influx_database} --environment");

      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      $machine->mustSucceed("influxdbUsername=influxdb dysnomia --type influx-database --operation restore --component ${influx_database} --environment");
      $result = $machine->mustSucceed("sleep 10; influx -database testdb -execute 'select * from cpu'");

      if($result =~ /serverB/) {
          print "InfluxDB query returns: serverB!\n";
      } else {
          die "InfluxDB cpu measurements should contain: serverB!\n";
      }
    '';
}
