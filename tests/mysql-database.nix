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
        rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
      };
        
      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      # Test MySQL activation script. Here we activate a database and
      # we check whether it is created. This test should succeed.
        
      $machine->waitForJob("mysql");
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation activate --component ${mysql_database} --environment");
      my $result = $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
    
      if($result =~ /Hello world/) {
          print "MySQL query returns: Hello world!\n";
      } else {
          die "MySQL table should contain: Hello world!\n";
      }
      
      # Activate the database again. It should proceed without doing anything.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation activate --component ${mysql_database} --environment");
      
      # Take a snapshot of the MySQL database.
      # This test should succeed.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation snapshot --component ${mysql_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/mysql-database/* | wc -l)\" = \"1\" ]");
      
      # Take another snapshot of the MySQL database. Because nothing changed, no
      # new snapshot is supposed to be taken. This test should succeed.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation snapshot --component ${mysql_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/mysql-database/* | wc -l)\" = \"1\" ]");
      
      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("echo \"insert into test values ('Bye world');\" | mysql --user=root --password=verysecret -N testdb");
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation snapshot --component ${mysql_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/mysql-database/* | wc -l)\" = \"2\" ]");
      
      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation collect-garbage --component ${mysql_database} --environment");
      $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
      
      # Deactivate the MySQL database. This test should succeed.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation deactivate --component ${mysql_database} --environment");
      
      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation collect-garbage --component ${mysql_database} --environment");
      $machine->mustFail("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
      
      # Activate the MySQL database again. This test should succeed.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation activate --component ${mysql_database} --environment");
      
      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation restore --component ${mysql_database} --environment");
      $result = $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
        
      if($result =~ /Bye world/) {
          print "MySQL query returns: Bye world!\n";
      } else {
          die "MySQL table should contain: Bye world!\n";
      }
    '';
}
