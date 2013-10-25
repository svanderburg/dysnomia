{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
}:

let
  pkgs = import nixpkgs {};
  
  jobs = rec {
    tarball =
      { dysnomia ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      }:

      with pkgs;

      releaseTools.sourceTarball {
        name = "dysnomia-tarball";
        version = builtins.readFile ./version;
        src = dysnomia;
        inherit officialRelease;

        buildInputs = [];
      };

    build =
      { tarball ? jobs.tarball {}
      , enableApacheWebApplication ? false
      , enableAxis2WebService ? false
      , enableEjabberdDump ? false
      , enableMySQLDatabase ? false
      , enablePostgreSQLDatabase ? false
      , enableTomcatWebApplication ? false
      , enableMongoDatabase ? false
      , enableSubversionRepository ? false
      , catalinaBaseDir ? "/var/tomcat"
      }:

      pkgs.lib.genAttrs systems (system:
        with import nixpkgs { inherit system; };
        
        releaseTools.nixBuild {
          name = "dysnomia";
          version = builtins.readFile ./version;
          src = tarball;
        
          preConfigure = stdenv.lib.optionalString enableEjabberdDump "export PATH=$PATH:${ejabberd}/sbin";

          configureFlags = ''
            ${if enableApacheWebApplication then "--with-apache" else "--without-apache"}
            ${if enableAxis2WebService then "--with-axis2" else "--without-axis2"}
            ${if enableEjabberdDump then "--with-ejabberd" else "--without-ejabberd"}
            ${if enableMySQLDatabase then "--with-mysql" else "--without-mysql"}
            ${if enablePostgreSQLDatabase then "--with-postgresql" else "--without-postgresql"}
            ${if enableMongoDatabase then "--with-mongodb" else "--without-mongodb"}
            ${if enableTomcatWebApplication then "--with-tomcat=${catalinaBaseDir}" else "--without-tomcat"}
            ${if enableSubversionRepository then "--with-subversion" else "--without-subversion"}
          '';
        
          buildInputs = []
            ++ stdenv.lib.optional enableEjabberdDump ejabberd
            ++ stdenv.lib.optional enableMySQLDatabase mysql
            ++ stdenv.lib.optional enablePostgreSQLDatabase postgresql
            ++ stdenv.lib.optional enableMongoDatabase mongodb
            ++ stdenv.lib.optional enableSubversionRepository subversion;
        }
      );
      
      tests = 
        { nixos ? <nixos> }:
        
        with pkgs;
        
        let
          dysnomia = builtins.getAttr (builtins.currentSystem) (build {
            enableApacheWebApplication = true;
            enableAxis2WebService = true;
            enableEjabberdDump = true;
            enableMySQLDatabase = true;
            enablePostgreSQLDatabase = true;
            enableMongoDatabase = true;
            enableTomcatWebApplication = true;
            enableSubversionRepository = true;
          });
          
          # Test services
          
          mysql_database = import ./tests/deployment/mysql-database.nix {
            inherit stdenv;
          };
          
          postgresql_database = import ./tests/deployment/postgresql-database.nix {
            inherit stdenv;
          };
          
          mongo_database = import ./tests/deployment/mongo-database.nix {
            inherit stdenv;
          };
          
          tomcat_webapplication = import ./tests/deployment/tomcat-webapplication.nix {
            inherit stdenv jdk;
          };
          
          axis2_webservice = import ./tests/deployment/axis2-webservice.nix {
            inherit stdenv jdk;
          };
          
          apache_webapplication = import ./tests/deployment/apache-webapplication.nix {
            inherit stdenv;
          };
          
          wrapper = import ./tests/deployment/wrapper.nix {
            inherit stdenv;
          };
          
          process = import ./tests/deployment/process.nix {
            inherit stdenv;
          };
          
          ejabberd_dump = import ./tests/deployment/ejabberd-dump.nix {
            inherit stdenv;
          };
          
          subversion_repository = import ./tests/deployment/subversion-repository.nix {
            inherit stdenv;
          };
        in
        
        with import "${nixos}/lib/testing.nix" { system = builtins.currentSystem; };
        
        {
          install = simpleTest {
            nodes = {
              machine = {config, pkgs, ...}:
              
              {
                virtualisation.memorySize = 1024;
                virtualisation.diskSize = 4096;
                
                services.mysql = {
                  enable = true;
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
                
                # Test echo activation script. Here we just invoke the activate
                # and deactivation steps. This test should succeed.
                $machine->mustSucceed("dysnomia --type echo --operation activate --component ${wrapper} --environment");
                $machine->mustSucceed("dysnomia --type echo --operation deactivate --component ${wrapper} --environment");
                
                # Test wrapper activation script. Here we invoke the wrapper
                # of a certain service. On activation it writes a state file in
                # the temp folder. After a while we deactivate it and we check
                # if the state file is removed. This test should succeed.
                
                $machine->mustSucceed("dysnomia --type wrapper --operation activate --component ${wrapper} --environment");
                $machine->mustSucceed("sleep 5; [ \"\$(cat /tmp/wrapper.state)\" = \"wrapper active\" ]");
                $machine->mustSucceed("dysnomia --type wrapper --operation deactivate --component ${wrapper} --environment");
                $machine->mustSucceed("sleep 5; [ ! -f /tmp/wrapper.state ]");
                
                # Test process activation script. Here we start a process which
                # loops forever. We check whether it has been started and
                # then we deactivate it again and verify whether it has been
                # stopped. This test should succeed.
                
                $machine->mustSucceed("dysnomia --type process --operation activate --component ${process} --environment");
                $machine->mustSucceed("sleep 5");
                $machine->mustSucceed("[ \"\$(systemctl status disnix-\$(basename ${process}) | grep \"Active: active\")\" != \"\" ]");
                $machine->mustSucceed("sleep 5");
                $machine->mustSucceed("dysnomia --type process --operation deactivate --component ${process} --environment");
                $machine->mustSucceed("[ \"\$(systemctl status disnix-\$(basename ${process}) | grep \"Active: inactive\")\" != \"\" ]");
                
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
                
                $machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret dysnomia --type mysql-database --operation deactivate --component ${mysql_database} --environment");
                
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
                
                $machine->mustSucceed("postgresqlUsername=root dysnomia --type postgresql-database --operation deactivate --component ${postgresql_database} --environment");
                
                # Test MongoDB activation scripts. Deploys a MongoDB instance,
                # inserts some data, verifies whether it can be accessed, then
                # undeploys it again and checks whether it becomes inaccessible.
                # This test should succeed.
                
                $machine->waitForJob("mongodb");
                $machine->mustSucceed("dysnomia --type mongo-database --operation activate --component ${mongo_database} --environment");
                $machine->mustSucceed("[ \"\$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" != \"\" ]");
                $machine->mustSucceed("dysnomia --type mongo-database --operation deactivate --component ${mongo_database} --environment");
                $machine->mustSucceed("[ \"\$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" = \"\" ]");
                
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
                $machine->mustFail("sleep 3; curl --fail --user admin:admin http://localhost:5280/admin"); # !!! We need to wait for a while even though ejabberd is running
                $machine->mustSucceed("dysnomia --type ejabberd-dump --operation activate --component ${ejabberd_dump} --environment");
                $machine->mustSucceed("curl --fail --user admin:admin http://localhost:5280/admin");
                $machine->mustSucceed("dysnomia --type ejabberd-dump --operation deactivate --component ${ejabberd_dump} --environment");
                
                # Test subversion activation script. We import a repository
                # then we do a checkout and see whether it succeeds.
                # This test should succeed.
                
                $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment");
                $machine->mustSucceed("${subversion}/bin/svn co file:///repos/testrepos");
                $machine->mustSucceed("[ -e testrepos/index.php ]");
                $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation deactivate --component ${subversion_repository} --environment");
                
                # Test NixOS configuration activation script. We activate the current
                # NixOS configuration
                
                $machine->mustSucceed("disableNixOSSystemProfile=1 testNixOS=1 dysnomia --type nixos-configuration --operation activate --component /var/run/current-system --environment");
              '';
          };
          
          frontend = 
            let
              mysql_container = writeTextFile {
                name = "mysql-container";
                text = ''
                  type=mysql-database
                  mysqlUsername=root
                  mysqlPassword=verysecret
                '';
              };
            in
            simpleTest {
              nodes = {
                machine = {config, pkgs, ...}:
              
                {
                  services.mysql = {
                    enable = true;
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
                '';
          };
    };
  };
in jobs
