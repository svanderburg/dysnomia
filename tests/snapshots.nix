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
  mysql_database = import ./deployment/mysql-database.nix {
    inherit stdenv;
  };

  mysql_container = writeTextFile {
    name = "mysql-container";
    text = ''
      type=mysql-database
      mysqlSocket=/run/mysqld/mysqld.sock
    '';
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      services.mysql = {
        enable = true;
        package = pkgs.mysql;
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      start_all()

      machine.wait_for_unit("mysql")

      # Test MySQL module. Here we activate a database and
      # we check whether it is created. This test should succeed.

      machine.succeed(
          "dysnomia --operation activate --component ${mysql_database} --container ${mysql_container}"
      )
      result = machine.succeed("echo 'select * from test' | mysql -N testdb")

      if "Hello world" in result:
          print("MySQL query returns: Hello world!")
      else:
          raise Exception("MySQL table should contain: Hello world!")

      # Create a snapshot of the current database.
      machine.succeed(
          "dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}"
      )

      # Add another record and create another snapshot. We need this for future
      # tests.

      machine.succeed("echo \"insert into test values ('Two');\" | mysql -N testdb")
      machine.succeed(
          "dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}"
      )

      # Add yet another record and snapshot. We need this for future tests.

      machine.succeed("echo \"insert into test values ('Three');\" | mysql -N testdb")
      machine.succeed(
          "dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}"
      )

      # Query all snapshots and check if there are actually three of them
      result = machine.succeed(
          "dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l"
      )

      if int(result) == 3:
          print("We have three snapshots!")
      else:
          raise Exception("Expecting three snapshots!")

      # Query latest snapshot and check if the 'Three' record is in it

      lastSnapshot = machine.succeed(
          "dysnomia-snapshots --query-latest --container mysql-container --component ${mysql_database}"
      )
      lastResolvedSnapshot = machine.succeed(
          "dysnomia-snapshots --resolve {}".format(lastSnapshot)
      )

      machine.succeed(
          '[ "\$(xzgrep \'Three\' {}/dump.sql.xz)" != "" ]'.format(lastResolvedSnapshot[:-1])
      )

      # We should have 3 generation snapshot links
      result = machine.succeed(
          "ls /var/state/dysnomia/generations/mysql-container/testdb | wc -l"
      )

      if int(result) == 3:
          print("We have three generation links!")
      else:
          raise Exception("We should have three generation links!")

      # Create another snapshot. Since nothing has changed we should have an
      # equal amount of generation symlinks.

      machine.succeed(
          "dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}"
      )
      result = machine.succeed(
          "ls /var/state/dysnomia/generations/mysql-container/testdb | wc -l"
      )

      if int(result) == 3:
          print("We have three generation links!")
      else:
          raise Excpetion("We should have three generation links!")

      # Print missing snapshot paths. The former path should exist, the latter
      # should not.

      result = machine.succeed(
          "dysnomia-snapshots --print-missing {} mysql-container/testdb/foo".format(
              lastSnapshot[:-1]
          )
      )

      if result[:-1] == "mysql-container/testdb/foo":
          print("Invalid path contains the foo path!")
      else:
          raise Exception("Invalid path should correspond to the foo path only!")

      # Run the garbage collector and check whether only the last snapshot exists

      machine.succeed("dysnomia-snapshots --gc")
      result = machine.succeed(
          "dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l"
      )

      if int(result) == 1:
          print("Only one snapshot left!")
      else:
          raise Exception("There should be only one snapshot left!")

      machine.succeed('[ -e "{}" ]'.format(lastResolvedSnapshot[:-1]))

      # Make a copy of the last snapshot, delete all snapshots and import it again
      # Finally, check whether the imported snapshot is the right one.
      machine.succeed("mkdir -p /tmp/snapshots")
      machine.succeed("cp -av {} /tmp/snapshots".format(lastResolvedSnapshot[:-1]))
      machine.succeed("dysnomia-snapshots --gc --keep 0")
      result = machine.succeed(
          "dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l"
      )

      if int(result) == 0:
          print("No snapshots left!")
      else:
          raise Exception("There should be no snapshots left!")

      machine.succeed(
          "dysnomia-snapshots --import --container mysql-container --component ${mysql_database} /tmp/snapshots/*"
      )
      machine.succeed(
          '[ "$(xzgrep \'Three\' {}/dump.sql.xz)" != "" ]'.format(lastResolvedSnapshot[:-1])
      )

      # Add another record and create another snapshot. We need this for future
      # tests.
      machine.succeed("echo \"insert into test values ('Four');\" | mysql -N testdb")
      machine.succeed(
          "dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}"
      )

      result = machine.succeed(
          "dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l"
      )

      if int(result) == 2:
          print("We have two snapshots!")
      else:
          raise Exception("There should be two snapshots!")

      # Delete the record we just created. Now we end up in a state that is
      # identical to the one before it.

      machine.succeed("echo \"delete from test where test = 'Four';\" | mysql -N testdb")
      machine.succeed(
          "dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}"
      )

      if int(result) == 2:
          print("We have two snapshots!")
      else:
          raise Exception("There should be two snapshots!")

      # Do a garbage collect and verify whether the last snapshot is the correct
      # one. Despite two generation symlinks referring to it, it should not be
      # accidentally removed.

      machine.succeed("dysnomia-snapshots --gc")

      lastSnapshot = machine.succeed(
          "dysnomia-snapshots --query-latest --container mysql-container --component ${mysql_database}"
      )
      lastResolvedSnapshot = machine.succeed(
          "dysnomia-snapshots --resolve {}".format(lastSnapshot)
      )
      machine.succeed(
          '[ "$(xzgrep \'Four\' {}/dump.sql.xz)" = "" ]'.format(lastResolvedSnapshot[:-1])
      )

      # Import a snapshot store path which should simply create a symlink only
      # and refer to the contents of the corresponding snapshot taken.

      machine.succeed(
          "dysnomia-snapshots --import --container mysql-container --component ${mysql_database} {}".format(
              lastResolvedSnapshot[:-1]
          )
      )
      result = machine.succeed(
          "dysnomia-snapshots --query-latest --container mysql-container --component ${mysql_database}"
      )
      machine.succeed(
          '[ "$(xzgrep \'Four\' {}/dump.sql.xz)" = "" ]'.format(lastResolvedSnapshot[:-1])
      )

      # Deactivate the MySQL database
      machine.succeed(
          "dysnomia --operation deactivate --component ${mysql_database} --container ${mysql_container}"
      )

      # Do a check of the snapshots. It should succeed because we know there is
      # no snapshot that we have tampered with.
      machine.succeed(
          "dysnomia-snapshots --query-all --check --container mysql-container --component ${mysql_database}"
      )

      # We now sabotage the snapshot and we check again. Now it should fail
      # because the hash no longer matches
      machine.succeed("echo '12345' > {}/dump.sql.xz".format(lastResolvedSnapshot[:-1]))
      machine.fail(
          "dysnomia-snapshots --query-all --check --container mysql-container --component ${mysql_database}"
      )
  '';
}
