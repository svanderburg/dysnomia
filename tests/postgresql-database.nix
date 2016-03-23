{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enablePostgreSQLDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  # Test services
  
  postgresql_database = import ./deployment/postgresql-database.nix {
    inherit stdenv;
  };
in
makeTest {
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
      startAll;
      
      # Test PostgreSQL activation script. Here we activate a database
      # and we check whether it is created. This test should succeed.
        
      $machine->waitForJob("postgresql");
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation activate --component ${postgresql_database} --environment");
      my $result = $machine->mustSucceed("echo 'select * from test' | psql --file - testdb");
        
      if($result =~ /Hello world/) {
          print "PostgreSQL query returns: Hello world!\n";
      } else {
          die "PostgreSQL table should contain: Hello world!\n";
      }
      
      # Activate the database again. It should proceed without doing anything.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation activate --component ${postgresql_database} --environment");
      
      # Take a snapshot of the PostgreSQL database.
      # This test should succeed.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation snapshot --component ${postgresql_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/postgresql-database/* | wc -l)\" = \"1\" ]");
      
      # Take another snapshot of the PostgreSQL database. Because nothing
      # changed, no new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation snapshot --component ${postgresql_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/postgresql-database/* | wc -l)\" = \"1\" ]");
      
      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("echo \"insert into test values ('Bye world');\" | psql --file - testdb");
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation snapshot --component ${postgresql_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/postgresql-database/* | wc -l)\" = \"2\" ]");
      
      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation collect-garbage --component ${postgresql_database} --environment");
      $machine->mustSucceed("echo 'select * from test;' | psql --file - testdb");
      
      # Deactivate the PostgreSQL database again. This test should succeed.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation deactivate --component ${postgresql_database} --environment");
      
      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation collect-garbage --component ${postgresql_database} --environment");
      $machine->mustFail("echo 'select * from test;' | psql --file - testdb");
      
      # Activate the PostgreSQL database again. This test should succeed.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation activate --component ${postgresql_database} --environment");
      
      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation restore --component ${postgresql_database} --environment");
      $result = $machine->mustSucceed("echo 'select * from test' | psql --file - testdb");
      
      if($result =~ /Bye world/) {
          print "PostgreSQL query returns: Bye world!\n";
      } else {
          die "PostgreSQL table should contain: Bye world!\n";
      }
    '';
}
