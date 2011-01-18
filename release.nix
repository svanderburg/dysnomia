{ nixpkgs ? /etc/nixos/nixpkgs }:

let
  jobs = rec {
    tarball =
      { disnix_activation_scripts ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      }:

      with import nixpkgs {};

      releaseTools.sourceTarball {
        name = "disnix-activation-scripts-tarball";
        version = builtins.readFile ./version;
        src = disnix_activation_scripts;
        inherit officialRelease;

        buildInputs = [ ];
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , enableApacheWebApplication ? false
      , enableAxis2WebService ? false
      , enableEjabberdDump ? false
      , enableMySQLDatabase ? false
      , enablePostgreSQLDatabase ? false
      , enableTomcatWebApplication ? false
      , enableSubversionRepository ? false
      , catalinaBaseDir ? "/var/tomcat"
      }:

      with import nixpkgs { inherit system; };

      releaseTools.nixBuild {
        name = "disnix-activation-scripts";
        src = tarball;
	
	preConfigure =
	  ''
	    ${stdenv.lib.optionalString enableEjabberdDump "export PATH=$PATH:${ejabberd}/sbin"}
	  '';

        configureFlags = 
	  ''
            ${if enableApacheWebApplication then "--with-apache" else "--without-apache"}
	    ${if enableAxis2WebService then "--with-axis2" else "--without-axis2"}
	    ${if enableEjabberdDump then "--with-ejabberd" else "--without-ejabberd"}
	    ${if enableMySQLDatabase then "--with-mysql" else "--without-mysql"}
	    ${if enablePostgreSQLDatabase then "--with-postgresql" else "--without-postgresql"}
	    ${if enableTomcatWebApplication then "--with-tomcat=${catalinaBaseDir}" else "--without-tomcat"}
	    ${if enableSubversionRepository then "--with-subversion" else "--without-subversion"}
	  '';

        buildInputs = []
	              ++ stdenv.lib.optional enableEjabberdDump ejabberd
		      ++ stdenv.lib.optional enableMySQLDatabase mysql
		      ++ stdenv.lib.optional enablePostgreSQLDatabase postgresql
		      ++ stdenv.lib.optional enableSubversionRepository subversion;
      };
      
      tests = 
        { nixos ? /etc/nixos/nixos }:
	
	with import nixpkgs {};
	
	let
          disnix_activation_scripts = build {
	    system = "x86_64-linux";
	    enableApacheWebApplication = true;
	    enableAxis2WebService = true;
	    enableEjabberdDump = true;
	    enableMySQLDatabase = true;
	    enablePostgreSQLDatabase = true;
	    enableTomcatWebApplication = true;
	    enableSubversionRepository = true;
	  };
	  
	  # Test services
	  
	  mysql_database = import ./tests/deployment/mysql-database.nix {
	    inherit stdenv;
	  };
	  
	  postgresql_database = import ./tests/deployment/postgresql-database.nix {
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
	
	with import "${nixos}/lib/testing.nix" { inherit nixpkgs; system = "x86_64-linux"; services = null; };
	
	{
          install = simpleTest {
	    nodes = {
	      machine = {config, pkgs, ...}:
	      
	      {
	        services.mysql = {
		  enable = true;
		  rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
		};
		services.postgresql = {
		  enable = true;
		};
		services.ejabberd.enable = true;
		services.httpd = {
		  enable = true;
		  adminAddr = "foo@bar.com";
		  documentRoot = "/var/www";
		};
		services.tomcat.enable = true;
		services.tomcat.axis2.enable = true;
		
		environment.systemPackages = [ disnix_activation_scripts ];
	      };
	    };
	    testScript =
	      ''
	        startAll;
		
		# Test echo activation script. Here we just invoke the activate
		# and deactivation steps. This test should succeed.
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/echo activate hello");
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/echo deactivate hello");				
		
		# Test wrapper activation script. Here we invoke the wrapper
		# of a certain service. This service spawns a process which
		# loops. We checks whether it is activated.
		# After a while we deactivate it and we check if it is indeed
		# deactivated. This test should succeed.
		
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/wrapper activate ${wrapper}");
		$machine->mustSucceed("[ \"\$(pgrep -f ${wrapper}/bin/loop)\" != \"\" ]");
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/wrapper deactivate ${wrapper}");
		$machine->mustSucceed("[ \"\$(pgrep -f ${wrapper}/bin/loop)\" = \"\" ]");
		
		# Test process activation script. Here we start a process which
		# loops forever. We check whether it has been started and
		# then we deactivate it again and verify whether it has been
		# stopped. This test should succeed.
		
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/process activate ${process}");
		$machine->mustSucceed("sleep 5");
		$machine->mustSucceed("[ \"\$(pgrep -f ${process}/bin/loop)\" != \"\" ]");
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/process deactivate ${process}");
		$machine->mustSucceed("sleep 5");
		$machine->mustSucceed("[ \"\$(pgrep -f ${process}/bin/loop)\" = \"\" ]");
		
		# Test Apache web application script. Here, we activate a small
		# static HTML website in the document root of Apache, then we
		# check whether it is available. Finally, we deactivate it again
		# and see whether is has become unavailable.
		# This test should succeed.
		
		$machine->waitForJob("httpd");
		$machine->mustSucceed("documentRoot=/var/www ${disnix_activation_scripts}/libexec/disnix/activation-scripts/apache-webapplication activate ${apache_webapplication}");
		$machine->mustSucceed("curl --fail http://localhost/test");
		$machine->mustSucceed("documentRoot=/var/www ${disnix_activation_scripts}/libexec/disnix/activation-scripts/apache-webapplication deactivate ${apache_webapplication}");
		$machine->mustFail("curl --fail http://localhost/test");
		
		# Test MySQL activation script. Here we activate a database and
		# we check whether it is created. This test should succeed.
		
		$machine->waitForJob("mysql");
		$machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret ${disnix_activation_scripts}/libexec/disnix/activation-scripts/mysql-database activate ${mysql_database}");
		my $result = $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
		
		if($result =~ /Hello world/) {
		    print "MySQL query returns: Hello world!\n";
		} else {
		    die "MySQL table should contain: Hello world!\n";
		}
		
		$machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret ${disnix_activation_scripts}/libexec/disnix/activation-scripts/mysql-database deactivate ${mysql_database}");
		
		# Test PostgreSQL activation script. Here we activate a database
		# and we check whether it is created. This test should succeed.
		
		$machine->waitForJob("postgresql");
		$machine->mustSucceed("postgresqlUsername=root ${disnix_activation_scripts}/libexec/disnix/activation-scripts/postgresql-database activate ${postgresql_database}");
		my $result = $machine->mustSucceed("echo 'select * from test' | psql --file - testdb");		
		
		if($result =~ /Hello world/) {
		    print "PostgreSQL query returns: Hello world!\n";
		} else {
		    die "PostgreSQL table should contain: Hello world!\n";
		}
		
		$machine->mustSucceed("postgresqlUsername=root ${disnix_activation_scripts}/libexec/disnix/activation-scripts/postgresql-database deactivate ${postgresql_database}");
		
		# Test Tomcat web application script. Deploys a tomcat web
		# application, verifies whether it can be accessed and then
		# undeploys it again and checks whether it becomes inaccessible.
		# This test should succeed.
		
		$machine->waitForJob("tomcat");
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/tomcat-webapplication activate ${tomcat_webapplication}");
		$machine->waitForFile("/var/tomcat/webapps/tomcat-webapplication");
		$machine->mustSucceed("curl --fail http://localhost:8080/tomcat-webapplication");
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/tomcat-webapplication deactivate ${tomcat_webapplication}");
		$machine->mustSucceed("while [ -e /var/tomcat/webapps/tomcat-webapplication ]; do echo 'Waiting to undeploy' >&2; sleep 1; done");
		$machine->mustFail("curl --fail http://localhost:8080/tomcat-webapplication");

                # Test Axis2 web service script.
		
		$machine->waitForFile("/var/tomcat/webapps/axis2");
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/axis2-webservice activate ${axis2_webservice}");
		$machine->mustSucceed("sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"); # !!! We must wait a while to let it become active
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/axis2-webservice deactivate ${axis2_webservice}");
		$machine->mustFail("sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"); # !!! We must wait a while to let it become inactive

		# Test ejabberd dump activation script. First we check if we can
		# login with an admin account (which is not the case), then
		# we activate the dump and we check the admin account again.
		# Now we should be able to login. This test should succeed.
		
		$machine->waitForJob("ejabberd");
		$machine->mustFail("sleep 3; curl --fail --user admin:admin http://localhost:5280/admin"); # !!! We need to wait for a while even though ejabberd is running
		$machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/ejabberd-dump activate ${ejabberd_dump}");
		$machine->mustSucceed("curl --fail --user admin:admin http://localhost:5280/admin");
                $machine->mustSucceed("${disnix_activation_scripts}/libexec/disnix/activation-scripts/ejabberd-dump deactivate ${ejabberd_dump}");
		
		# Test subversion activation script. We import a repository
		# then we do a checkout and see whether it succeeds.
		# This test should succeed.
		
		$machine->mustSucceed("svnBaseDir=/repos svnGroup=users ${disnix_activation_scripts}/libexec/disnix/activation-scripts/subversion-repository activate ${subversion_repository}");
		$machine->mustSucceed("${subversion}/bin/svn co file:///repos/testrepos");
		$machine->mustSucceed("[ -e testrepos/index.php ]");
		$machine->mustSucceed("svnBaseDir=/repos svnGroup=users ${disnix_activation_scripts}/libexec/disnix/activation-scripts/subversion-repository deactivate ${subversion_repository}");
		
		# Test NixOS configuration activation script. We activate the current
		# NixOS configuration
		
		$machine->mustSucceed("disableNixOSSystemProfile=1 testNixOS=1 ${disnix_activation_scripts}/libexec/disnix/activation-scripts/nixos-configuration activate /var/run/current-system");
	      '';
	  };
	};
  };
in jobs
