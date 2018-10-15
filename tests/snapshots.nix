{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableMySQLDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  mysql_database = import ./deployment/mysql-database.nix {
    inherit stdenv;
  };

  mysql_container = writeTextFile {
    name = "mysql-container";
    text = ''
      type=mysql-database
      mysqlUsername=root
      mysqlPassword=verysecret
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
        rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      startAll;

      # Test MySQL module. Here we activate a database and
      # we check whether it is created. This test should succeed.

      $machine->waitForJob("mysql");
      $machine->mustSucceed("dysnomia --operation activate --component ${mysql_database} --container ${mysql_container}");
      my $result = $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");

      if($result =~ /Hello world/) {
          print "MySQL query returns: Hello world!\n";
      } else {
          die "MySQL table should contain: Hello world!\n";
      }

      # Create a snapshot of the current database.
      $machine->mustSucceed("dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}");

      # Add another record and create another snapshot. We need this for future
      # tests.

      $machine->mustSucceed("echo \"insert into test values ('Two');\" | mysql --user=root --password=verysecret -N testdb");
      $machine->mustSucceed("dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}");

      # Add yet another record and snapshot. We need this for future tests.

      $machine->mustSucceed("echo \"insert into test values ('Three');\" | mysql --user=root --password=verysecret -N testdb");
      $machine->mustSucceed("dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}");

      # Query all snapshots and check if there are actually three of them
      $result = $machine->mustSucceed("dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l");

      if($result == 3) {
          print "We have three snapshots!\n";
      } else {
          die "Expecting three snapshots!";
      }

      # Query latest snapshot and check if the 'Three' record is in it

      my $lastSnapshot = $machine->mustSucceed("dysnomia-snapshots --query-latest --container mysql-container --component ${mysql_database}");
      my $lastResolvedSnapshot = $machine->mustSucceed("dysnomia-snapshots --resolve ".$lastSnapshot);
      $machine->mustSucceed("[ \"\$(xzgrep 'Three' ".(substr $lastResolvedSnapshot, 0, -1)."/dump.sql.xz)\" != \"\" ]");

      # We should have 3 generation snapshot links
      $result = $machine->mustSucceed("ls /var/state/dysnomia/generations/mysql-container/testdb | wc -l");

      if($result == 3) {
          print "We have three generation links!\n";
      } else {
          die "We should have three generation links!";
      }

      # Create another snapshot. Since nothing has changed we should have an
      # equal amount of generation symlinks.

      $machine->mustSucceed("dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}");
      $result = $machine->mustSucceed("ls /var/state/dysnomia/generations/mysql-container/testdb | wc -l");

      if($result == 3) {
          print "We have three generation links!\n";
      } else {
          die "We should have three generation links!";
      }

      # Print missing snapshot paths. The former path should exist, the latter
      # should not.

      $result = $machine->mustSucceed("dysnomia-snapshots --print-missing ".(substr $lastSnapshot, 0, -1)." mysql-container/testdb/foo");

      if((substr $result, 0, -1) eq "mysql-container/testdb/foo") {
          print "Invalid path contains the foo path!\n";
      } else {
          die "Invalid path should correspond to the foo path only!";
      }

      # Run the garbage collector and check whether only the last snapshot exists

      $machine->mustSucceed("dysnomia-snapshots --gc");
      $result = $machine->mustSucceed("dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l");

      if($result == 1) {
          print "Only one snapshot left!\n";
      } else {
          die "There should be only one snapshot left!";
      }

      $machine->mustSucceed("[ -e ".(substr $lastResolvedSnapshot, 0, -1)." ]");

      # Make a copy of the last snapshot, delete all snapshots and import it again
      # Finally, check whether the imported snapshot is the right one.
      $machine->mustSucceed("mkdir -p /tmp/snapshots");
      $machine->mustSucceed("cp -av ".(substr $lastResolvedSnapshot, 0, -1)." /tmp/snapshots");
      $machine->mustSucceed("dysnomia-snapshots --gc --keep 0");
      $result = $machine->mustSucceed("dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l");

      if($result == 0) {
          print "No snapshots left!\n";
      } else {
          die "There should be no snapshots left!";
      }

      $machine->mustSucceed("dysnomia-snapshots --import --container mysql-container --component ${mysql_database} /tmp/snapshots/*");
      $machine->mustSucceed("[ \"\$(xzgrep 'Three' ".(substr $lastResolvedSnapshot, 0, -1)."/dump.sql.xz)\" != \"\" ]");

      # Add another record and create another snapshot. We need this for future
      # tests.
      $machine->mustSucceed("echo \"insert into test values ('Four');\" | mysql --user=root --password=verysecret -N testdb");
      $machine->mustSucceed("dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}");

      $result = $machine->mustSucceed("dysnomia-snapshots --query-all --container mysql-container --component ${mysql_database} | wc -l");

      if($result == 2) {
          print "We have two snapshots!\n";
      } else {
          die "There should be two snapshots!";
      }

      # Delete the record we just created. Now we end up in a state that is
      # identical to the one before it.

      $machine->mustSucceed("echo \"delete from test where test = 'Four';\" | mysql --user=root --password=verysecret -N testdb");
      $machine->mustSucceed("dysnomia --operation snapshot --component ${mysql_database} --container ${mysql_container}");

      if($result == 2) {
          print "We have two snapshots!\n";
      } else {
          die "There should be two snapshots!";
      }

      # Do a garbage collect and verify whether the last snapshot is the correct
      # one. Despite two generation symlinks referring to it, it should not be
      # accidentally removed.

      $machine->mustSucceed("dysnomia-snapshots --gc");

      $lastSnapshot = $machine->mustSucceed("dysnomia-snapshots --query-latest --container mysql-container --component ${mysql_database}");
      $lastResolvedSnapshot = $machine->mustSucceed("dysnomia-snapshots --resolve ".$lastSnapshot);
      $machine->mustSucceed("[ \"\$(xzgrep 'Four' ".(substr $lastResolvedSnapshot, 0, -1)."/dump.sql.xz)\" = \"\" ]");

      # Import a snapshot store path which should simply create a symlink only
      # and refer to the contents of the corresponding snapshot taken.

      $machine->mustSucceed("dysnomia-snapshots --import --container mysql-container --component ${mysql_database} ".(substr $lastResolvedSnapshot, 0, -1));
      $result = $machine->mustSucceed("dysnomia-snapshots --query-latest --container mysql-container --component ${mysql_database}");
      $machine->mustSucceed("[ \"\$(xzgrep 'Four' ".(substr $lastResolvedSnapshot, 0, -1)."/dump.sql.xz)\" = \"\" ]");

      # Deactivate the MySQL database
      $machine->mustSucceed("dysnomia --operation deactivate --component ${mysql_database} --container ${mysql_container}");

      # Do a check of the snapshots. It should succeed because we know there is
      # no snapshot that we have tampered with.
      $machine->mustSucceed("dysnomia-snapshots --query-all --check --container mysql-container --component ${mysql_database}");

      # We now sabotage the snapshot and we check again. Now it should fail
      # because the hash no longer matches
      $machine->mustSucceed("echo '12345' > ".(substr $lastResolvedSnapshot, 0, -1)."/dump.sql.xz");
      $machine->mustFail("dysnomia-snapshots --query-all --check --container mysql-container --component ${mysql_database}");
  '';
}
