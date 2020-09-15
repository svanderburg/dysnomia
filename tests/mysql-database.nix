{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableMySQLDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  mysql_database = import ./deployment/mysql-database.nix {
    inherit stdenv;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.mysql = {
        enable = true;
        package = pkgs.mysql;
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_num_of_snapshot_generations(num):
          actual_num = machine.succeed(
              "ls /var/state/dysnomia/snapshots/mysql-database/* | wc -l"
          )

          if int(num) != int(actual_num):
              raise Exception(
                  "Expecting {num} snapshot generations, but we have: {actual_num}".format(
                      num=num, actual_num=actual_num
                  )
              )


      start_all()

      mysqlCredentials = "mysqlUsername=root mysqlPassword=verysecret"

      # Test MySQL module. Here we activate a database and
      # we check whether it is created. This test should succeed.

      machine.wait_for_unit("mysql")

      machine.succeed("mysqladmin -u root password verysecret")

      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation activate --component ${mysql_database} --environment"
      )
      result = machine.succeed(
          "echo 'select * from test' | mysql --user=root --password=verysecret -N testdb"
      )

      if "Hello world" in result:
          print("MySQL query returns: Hello world!")
      else:
          raise Exception("MySQL table should contain: Hello world!")

      # Activate the database again. It should proceed without doing anything.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation activate --component ${mysql_database} --environment"
      )

      # Take a snapshot of the MySQL database.
      # This test should succeed.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation snapshot --component ${mysql_database} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Take another snapshot of the MySQL database. Because nothing changed, no
      # new snapshot is supposed to be taken. This test should succeed.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation snapshot --component ${mysql_database} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      machine.succeed(
          "echo \"insert into test values ('Bye world');\" | mysql --user=root --password=verysecret -N testdb"
      )

      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation snapshot --component ${mysql_database} --environment"
      )
      check_num_of_snapshot_generations(2)

      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation collect-garbage --component ${mysql_database} --environment"
      )
      machine.succeed(
          "echo 'select * from test' | mysql --user=root --password=verysecret -N testdb"
      )

      # Deactivate the MySQL database. This test should succeed.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation deactivate --component ${mysql_database} --environment"
      )

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation deactivate --component ${mysql_database} --environment"
      )

      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation collect-garbage --component ${mysql_database} --environment"
      )
      machine.fail(
          "echo 'select * from test' | mysql --user=root --password=verysecret -N testdb"
      )

      # Activate the MySQL database again. This test should succeed.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation activate --component ${mysql_database} --environment"
      )

      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      machine.succeed(
          mysqlCredentials
          + " dysnomia --type mysql-database --operation restore --component ${mysql_database} --environment"
      )
      result = machine.succeed(
          "echo 'select * from test' | mysql --user=root --password=verysecret -N testdb"
      )

      if "Bye world" in result:
          print("MySQL query returns: Bye world!")
      else:
          raise Exception("MySQL table should contain: Bye world!")
    '';
}
