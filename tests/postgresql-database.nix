{ buildFun,
  makeTest,
  pkgs,
  stdenv,
  tarball
}:

let
  dysnomia = buildFun {
    inherit pkgs tarball;
    enablePostgreSQLDatabase = true;
  };

  # Test services

  postgresql_database = import ./deployment/postgresql-database.nix {
    inherit stdenv;
  };
in
makeTest {
  name = "postgresql-database";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.postgresql = {
        enable = true;
        package = pkgs.postgresql;
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_num_of_snapshot_generations(num):
          actual_num = machine.succeed(
              "ls /var/state/dysnomia/snapshots/postgresql-database/* | wc -l"
          )

          if int(num) != int(actual_num):
              raise Exception(
                  "Expecting {num} snapshot generations, but we have: {actual_num}".format(
                      num=num, actual_num=actual_num
                  )
              )


      start_all()

      postgresqlCredentials = "postgresqlUsername=postgres"

      machine.wait_for_unit("postgresql")

      # Test PostgreSQL module. Here we activate a database
      # and we check whether it is created. This test should succeed.

      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation activate --component ${postgresql_database} --environment"
      )
      result = machine.succeed(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      if "Hello world" in result:
          print("PostgreSQL query returns: Hello world!")
      else:
          raise Exception("PostgreSQL table should contain: Hello world!")

      # Activate the database again. It should proceed without doing anything.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation activate --component ${postgresql_database} --environment"
      )

      # Take a snapshot of the PostgreSQL database.
      # This test should succeed.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation snapshot --component ${postgresql_database} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Take another snapshot of the PostgreSQL database. Because nothing
      # changed, no new snapshot is supposed to be taken. This test should
      # succeed.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation snapshot --component ${postgresql_database} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      machine.succeed(
          "echo \"insert into test values ('Bye world');\" | su -s /bin/sh postgres -c 'psql --file - testdb'"
      )
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation snapshot --component ${postgresql_database} --environment"
      )
      check_num_of_snapshot_generations(2)

      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation collect-garbage --component ${postgresql_database} --environment"
      )
      machine.succeed(
          "echo 'select * from test;' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      # Deactivate the PostgreSQL database again. This test should succeed.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation deactivate --component ${postgresql_database} --environment"
      )

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation deactivate --component ${postgresql_database} --environment"
      )

      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation collect-garbage --component ${postgresql_database} --environment"
      )
      machine.fail(
          "echo 'select * from test;' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      # Activate the PostgreSQL database again. This test should succeed.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation activate --component ${postgresql_database} --environment"
      )

      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      machine.succeed(
          postgresqlCredentials
          + " dysnomia --type postgresql-database --operation restore --component ${postgresql_database} --environment"
      )
      result = machine.succeed(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      if "Bye world" in result:
          print("PostgreSQL query returns: Bye world!")
      else:
          raise Exception("PostgreSQL table should contain: Bye world!")
    '';
}
