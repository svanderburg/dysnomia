{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableMySQLDatabase = true;
    enablePostgreSQLDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

makeTest {
  nodes = {
    machine = {config, pkgs, ...}:
    
    {
      imports = [ ../dysnomia-module.nix ];
      
      services.dysnomia = {
        enable = true;
        
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
      
      services.mysql = {
        enable = true;
        package = pkgs.mysql;
        rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
      };
      
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql;
      };
    };
  };
  
  testScript =
    ''
      startAll;
      
      $machine->waitForJob("mysql");
      $machine->waitForJob("postgresql");
      
      # Query the available containers. It should return a MySQL and a
      # PostgreSQL entry.
      
      my $result = $machine->mustSucceed("dysnomia-containers --query-containers");
      my @containers = split('\n', $result);
      
      if(scalar(grep(/mysql-database/, @containers)) == 1) {
          print "mysql-database is in the containers query!\n";
      } else {
          die "mysql-database should be in the containers query!";
      }
      
      if(scalar(grep(/postgresql-database/, @containers)) == 1) {
          print "postgresql-database is in the containers query!\n";
      } else {
          die "postgresql-database should be in the containers query!";
      }
      
      # Query the available components. It should return a MySQL and a
      # PostgreSQL database.
      
      $result = $machine->mustSucceed("dysnomia-containers --query-available-components");
      @containers = split('\n', $result);
      
      if(scalar(grep(/mysql-database\/testdb/, @containers)) == 1) {
          print "mysql-database/testdb is in the available components query!\n";
      } else {
          die "mysql-database/testdb should be in the available components query!";
      }
      
      if(scalar(grep(/postgresql-database\/testdb/, @containers)) == 1) {
          print "postgresql-database/testdb is in the available components query!\n";
      } else {
          die "postgresql-database/testdb should be in the available components query!";
      }
      
      # Query the activated components. It should return nothing, as we have not
      # activated anything yet.
      
      $result = $machine->mustSucceed("dysnomia-containers --query-activated-components");
      @containers = split('\n', $result);
      
      if(scalar(grep(/mysql-database\/testdb/, @containers)) == 0) {
          print "We have no activated components!\n";
      } else {
          die "We should have no activated components!\n";
      }
      
      # Deploy the available components.
      $machine->mustSucceed("dysnomia-containers --deploy");
      
      # Query the activated components. It should return the MySQL and
      # PostgreSQL database.
      
      $result = $machine->mustSucceed("dysnomia-containers --query-activated-components");
      @containers = split('\n', $result);
      
      if(scalar(grep(/mysql-database\/testdb/, @containers)) == 1) {
          print "mysql-database/testdb is in the activated components query!\n";
      } else {
          die "mysql-database/testdb should be in the activated components query!";
      }
      
      if(scalar(grep(/postgresql-database\/testdb/, @containers)) == 1) {
          print "postgresql-database/testdb is in the activated components query!\n";
      } else {
          die "postgresql-database/testdb should be in the activated components query!";
      }
      
      # Check whether the MySQL database has been created.
      $result = $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
    
      if($result =~ /Hello world/) {
          print "MySQL query returns: Hello world!\n";
      } else {
          die "MySQL table should contain: Hello world, instead we have: $result!\n";
      }
      
      # Check whether the PostgreSQL database has been created.
      $result = $machine->mustSucceed("echo 'select * from test' | psql --file - testdb");
      
      if($result =~ /Hello world/) {
          print "PostgreSQL query returns: Hello world!\n";
      } else {
          die "PostgreSQL table should contain: Hello world!\n";
      }
  '';
}
