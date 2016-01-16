{ nixpkgs, buildFun }:

let
  dysnomia = buildFun {
    system = builtins.currentSystem;
    enableApacheWebApplication = true;
    enableAxis2WebService = true;
    enableEjabberdDump = true;
    enableMySQLDatabase = true;
    enablePostgreSQLDatabase = true;
    enableMongoDatabase = true;
    enableTomcatWebApplication = true;
    enableSubversionRepository = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  # Test services
  
  mysql_database = import ./deployment/mysql-database.nix {
    inherit stdenv;
  };
  
  postgresql_database = import ./deployment/postgresql-database.nix {
    inherit stdenv;
  };
  
  mongo_database = import ./deployment/mongo-database.nix {
    inherit stdenv;
  };
  
  tomcat_webapplication = import ./deployment/tomcat-webapplication.nix {
    inherit stdenv jdk;
  };
  
  axis2_webservice = import ./deployment/axis2-webservice.nix {
    inherit stdenv jdk;
  };
  
  apache_webapplication = import ./deployment/apache-webapplication.nix {
    inherit stdenv;
  };

  ejabberd_dump = import ./deployment/ejabberd-dump.nix {
    inherit stdenv;
  };
  
  subversion_repository = import ./deployment/subversion-repository.nix {
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
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql;
      };
      services.mongodb.enable = true;
      services.ejabberd.enable = true;
      services.httpd = {
        enable = true;
        adminAddr = "foo@bar.com";
        documentRoot = "/var/www";
      };
      services.tomcat.enable = true;
      services.tomcat.axis2.enable = true;
        
      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      startAll;
      
      # Test Apache web application script. Here, we activate a small
      # static HTML website in the document root of Apache, then we
      # check whether it is available. Finally, we deactivate it again
      # and see whether is has become unavailable.
      # This test should succeed.
        
      $machine->waitForJob("httpd");
      $machine->mustSucceed("documentRoot=/var/www dysnomia --type apache-webapplication --operation activate --component ${apache_webapplication} --environment");
      $machine->mustSucceed("curl --fail http://localhost/test");
      $machine->mustSucceed("documentRoot=/var/www dysnomia --type apache-webapplication --operation deactivate --component ${apache_webapplication} --environment");
      $machine->mustFail("curl --fail http://localhost/test");
        
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
      
      # Test PostgreSQL activation script. Here we activate a database
      # and we check whether it is created. This test should succeed.
        
      $machine->waitForJob("postgresql");
      $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation activate --component ${postgresql_database} --environment");
      $result = $machine->mustSucceed("echo 'select * from test' | psql --file - testdb");
        
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
      
      # Test MongoDB activation scripts. Deploys a MongoDB instance,
      # inserts some data and verifies whether it can be accessed.
      # This test should succeed.
        
      $machine->waitForJob("mongodb");
      #$machine->mustSucceed("sleep 100"); # !!! We need some delay to run this smoothly
      $machine->mustSucceed("dysnomia --type mongo-database --operation activate --component ${mongo_database} --environment");
      $machine->mustSucceed("[ \"\$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" != \"\" ]");
      
      # Activate the Mongo database again and should not cause duplicate records. This test should succeed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation activate --component ${mongo_database} --environment");
      $machine->mustSucceed("[ \"\$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world' | wc -l)\" = \"1\" ]");
      
      # Take a snapshot of the Mongo database.
      # This test should succeed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation snapshot --component ${mongo_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/mongo-database/* | wc -l)\" = \"1\" ]");
      
      # Take another snapshot of the Mongo database. Because nothing changed, no
      # new snapshot is supposed to be taken. This test should succeed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation snapshot --component ${mongo_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/mongo-database/* | wc -l)\" = \"1\" ]");
      
      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("(echo 'use testdb;'; echo 'db.messages.save({ \"test\": \"test123\" });') | mongo");
      $machine->mustSucceed("dysnomia --type mongo-database --operation snapshot --component ${mongo_database} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/mongo-database/* | wc -l)\" = \"2\" ]");
      
      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation collect-garbage --component ${mongo_database} --environment");
      $machine->mustSucceed("[ \"\$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" != \"\" ]");
      
      # Deactivate the mongo database. This test should succeed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation deactivate --component ${mongo_database} --environment");
      
      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation collect-garbage --component ${mongo_database} --environment");
      $machine->mustFail("[ \"\$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" != \"\" ]");
      
      # Activate the mongo database again. This test should succeed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation activate --component ${mongo_database} --environment");
      
      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      $machine->mustSucceed("dysnomia --type mongo-database --operation restore --component ${mongo_database} --environment");
      $result = $machine->mustSucceed("(echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo");
      
      if($result =~ /test123/) {
          print "mongo query returns: test123!\n";
      } else {
          die "mongo collection should contain: test123!\n";
      }
      
      # Test Tomcat web application script. Deploys a tomcat web
      # application, verifies whether it can be accessed and then
      # undeploys it again and checks whether it becomes inaccessible.
      # This test should succeed.
        
      $machine->waitForJob("tomcat");
      $machine->mustSucceed("dysnomia --type tomcat-webapplication --operation activate --component ${tomcat_webapplication} --environment");
      $machine->waitForFile("/var/tomcat/webapps/tomcat-webapplication");
      $machine->mustSucceed("curl --fail http://localhost:8080/tomcat-webapplication");
      $machine->mustSucceed("dysnomia --type tomcat-webapplication --operation deactivate --component ${tomcat_webapplication} --environment");
      $machine->mustSucceed("while [ -e /var/tomcat/webapps/tomcat-webapplication ]; do echo 'Waiting to undeploy' >&2; sleep 1; done");
      $machine->mustFail("curl --fail http://localhost:8080/tomcat-webapplication");

      # Test Axis2 web service script.
      
      $machine->waitForFile("/var/tomcat/webapps/axis2");
      $machine->mustSucceed("dysnomia --type axis2-webservice --operation activate --component ${axis2_webservice} --environment");
      $machine->mustSucceed("sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"); # !!! We must wait a while to let it become active
      $machine->mustSucceed("dysnomia --type axis2-webservice --operation deactivate --component ${axis2_webservice} --environment");
      $machine->mustFail("sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"); # !!! We must wait a while to let it become inactive

      # Test ejabberd dump activation script. First we check if we can
      # login with an admin account (which is not the case), then
      # we activate the dump and we check the admin account again.
      # Now we should be able to login. This test should succeed.
        
      $machine->waitForJob("ejabberd");
      $machine->mustFail("curl --fail --user admin:admin http://localhost:5280/admin");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation activate --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("curl --fail --user admin:admin http://localhost:5280/admin");
      
      # Take a snapshot of the ejabberd database.
      # This test should succeed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/ejabberd-dump/* | wc -l)\" = \"1\" ]");
      
      # Take another snapshot of the ejabberd database. Because nothing changed, no
      # new snapshot is supposed to be taken. This test should succeed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/ejabberd-dump/* | wc -l)\" = \"1\" ]");
      
      # Make a modification (creating a new user) and take another snapshot.
      # Because something changed, a new snapshot is supposed to be taken. This
      # test should succeed.
      $machine->mustSucceed("su ejabberd -s /bin/sh -c \"ejabberdctl register newuser localhost newuser\"");
      $machine->mustSucceed("curl --fail --user newuser:newuser http://localhost:5280/admin");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation snapshot --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/ejabberd-dump/* | wc -l)\" = \"2\" ]");
      
      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation collect-garbage --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ -e /var/lib/ejabberd ]");
      
      # Deactivate the ejabberd database. This test should succeed.
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation deactivate --component ${ejabberd_dump} --environment");
      
      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("systemctl stop ejabberd");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation collect-garbage --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("[ ! -e /var/lib/ejabberd ]");
      
      # Activate the ejabberd database again. This test should succeed.
      $machine->mustSucceed("systemctl start ejabberd");
      $machine->waitForJob("ejabberd");
      $machine->mustSucceed("ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation activate --component ${ejabberd_dump} --environment");
      $machine->mustFail("curl --fail --user newuser:newuser http://localhost:5280/admin");
      
      # Restore the last snapshot and check whether it contains the recently
      # added user. This test should succeed.
      $machine->mustSucceed("sleep 3; ejabberdUser=ejabberd dysnomia --type ejabberd-dump --operation restore --component ${ejabberd_dump} --environment");
      $machine->mustSucceed("curl --fail --user newuser:newuser http://localhost:5280/admin");
      
      # Test Subversion activation script. We import a repository
      # then we do a checkout and see whether it succeeds.
      # This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment");
      $machine->mustSucceed("${subversion}/bin/svn co file:///repos/testrepos");
      $machine->mustSucceed("[ -e testrepos/index.php ]");
      
      # Activate the subversion repository again. It should not fail because of a double activation.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment");
      
      # Take a snapshot of the Subversion repository.
      # This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/subversion-repository/* | wc -l)\" = \"1\" ]");
      
      # Take another snapshot of the Subversion repository. Because nothing
      # changed, no new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/subversion-repository/* | wc -l)\" = \"1\" ]");
      
      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("cd testrepos; echo '<p>hello</p>' > hello.php; ${subversion}/bin/svn add hello.php; ${subversion}/bin/svn commit -m 'test commit'");
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/subversion-repository/* | wc -l)\" = \"2\" ]");
      
      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation collect-garbage --component ${subversion_repository} --environment");
      $machine->mustSucceed("cd testrepos; ${subversion}/bin/svn update");
      
      # Deactivate the Subversion repository. This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation deactivate --component ${subversion_repository} --environment");
    
      # Run the garbage collect operation. Since the repository has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation collect-garbage --component ${subversion_repository} --environment");
      $machine->mustFail("cd testrepos; ${subversion}/bin/svn update");
      
      # Activate the subversion repository again. This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment");
      
      # Restore the last snapshot and check whether it contains the recently
      # added file. This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation restore --component ${subversion_repository} --environment");
      $result = $machine->mustSucceed("[ -e testrepos/hello.php ]");
      
      # Test NixOS configuration activation script. We activate the current
      # NixOS configuration
      $machine->mustSucceed("disableNixOSSystemProfile=1 testNixOS=1 dysnomia --type nixos-configuration --operation activate --component /var/run/current-system --environment");
    '';
}
