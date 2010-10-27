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
      , enableTomcatWebApplication ? false
      , catalinaBaseDir ? "/var/tomcat"
      }:

      with import nixpkgs { inherit system; };

      releaseTools.nixBuild {
        name = "disnix-activation-scripts";
        src = tarball;

        configureFlags = 
	  ''
            ${if enableApacheWebApplication then "--with-apache" else "--without-apache"}
	    ${if enableAxis2WebService then "--with-axis2" else "--without-axis2"}
	    ${if enableEjabberdDump then "--with-ejabberd" else "--without-ejabberd"}
	    ${if enableMySQLDatabase then "--with-mysql" else "--without-mysql"}
	    ${if enableTomcatWebApplication then "--with-tomcat=${catalinaBaseDir}" else "--without-tomcat"}
	  '';

        buildInputs = []
	              ++ stdenv.lib.optional enableEjabberdDump ejabberd
		      ++ stdenv.lib.optional enableMySQLDatabase mysql;
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
	    enableTomcatWebApplication = true;
	  };
	  
	  testdb = import ./tests/deployment/mysql-database.nix { inherit stdenv; };
	  tomcat_webapplication = import ./tests/deployment/tomcat-webapplication.nix { inherit stdenv jdk; };
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
		services.ejabberd.enable = true;
		services.httpd = {
		  enable = true;
		  adminAddr = "foo@bar.com";
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
		
		# Test MySQL activation script. Here we activate a database and
		# we check whether it is created. This test should succeed.
		
		$machine->waitForJob("mysql");
		$machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret ${disnix_activation_scripts}/libexec/disnix/activation-scripts/mysql-database activate ${testdb}");
		my $result = $machine->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
		
		if($result =~ /Hello world/) {
		    print "MySQL query returns: Hello world!\n";
		} else {
		    die "MySQL table should contain: Hello world!\n";
		}
		
		$machine->mustSucceed("mysqlUsername=root mysqlPassword=verysecret ${disnix_activation_scripts}/libexec/disnix/activation-scripts/mysql-database deactivate ${testdb}");
		
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
	      '';
	  };
	};
  };
in jobs
