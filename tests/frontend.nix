{ nixpkgs, dysnomia }:

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
        
      $machine->mustSucceed("dysnomia --operation deactivate --component ${mysql_database} --container ${mysql_container}");
  '';
}
