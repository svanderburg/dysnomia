{ nixpkgs, buildFun }:

let
  dysnomia = buildFun {
    system = builtins.currentSystem;
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
      
      # Test MySQL activation script. Here we activate a database and
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
      
      $result = $machine->mustSucceed("dysnomia-store --query-all --container mysql-database --component ${mysql_database} | wc -l");
      
      if($result == 3) {
          print "We have three snapshots!\n";
      } else {
          die "Expecting three snapshots!";
      }
      
      # Query latest snapshot and check if the 'Three' record is in it
      
      my $lastSnapshot = $machine->mustSucceed("dysnomia-store --query-latest --container mysql-database --component ${mysql_database}");
      my $lastResolvedSnapshot = $machine->mustSucceed("dysnomia-store --resolve ".$lastSnapshot);
      $machine->mustSucceed("[ \"\$(xzgrep 'Three' ".(substr $lastResolvedSnapshot, 0, -1)."/dump.sql.xz)\" != \"\" ]");
      
      # Print missing snapshot paths. The former path should exist, the latter
      # should not.
      
      $result = $machine->mustSucceed("dysnomia-store --print-missing ".(substr $lastSnapshot, 0, -1)." mysql-database/testdb/foo");
      
      if((substr $result, 0, -1) eq "mysql-database/testdb/foo") {
          print "Invalid path contains the foo path!\n";
      } else {
          die "Invalid path should correspond to the foo path only!";
      }
      
      # Run the garbage collector and check whether only the last snapshot exists
      
      $machine->mustSucceed("dysnomia-store --gc");
      $result = $machine->mustSucceed("dysnomia-store --query-all --container mysql-database --component ${mysql_database} | wc -l");
      
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
      $machine->mustSucceed("dysnomia-store --gc --keep 0");
      $result = $machine->mustSucceed("dysnomia-store --query-all --container mysql-database --component ${mysql_database} | wc -l");
      
      if($result == 0) {
          print "No snapshots left!\n";
      } else {
          die "There should be no snapshots left!";
      }
      
      $machine->mustSucceed("dysnomia-store --import --container mysql-database --component ${mysql_database} /tmp/snapshots/*");
      $machine->mustSucceed("[ \"\$(xzgrep 'Three' ".(substr $lastResolvedSnapshot, 0, -1)."/dump.sql.xz)\" != \"\" ]");
      
      # Deactivate the MySQL database
      $machine->mustSucceed("dysnomia --operation deactivate --component ${mysql_database} --container ${mysql_container}");
  '';
}
