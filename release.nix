{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, dysnomia ? { outPath = ./.; rev = 1234; }
, officialRelease ? false
}:

let
  pkgs = import nixpkgs {};
  
  buildFun =
    { enableApacheWebApplication ? false
    , enableAxis2WebService ? false
    , enableEjabberdDump ? false
    , enableMySQLDatabase ? false
    , enablePostgreSQLDatabase ? false
    , enableTomcatWebApplication ? false
    , enableMongoDatabase ? false
    , enableSubversionRepository ? false
    , catalinaBaseDir ? "/var/tomcat"
    , jobTemplate ? "systemd"
    , system
    }:

    with import nixpkgs { inherit system; };

    releaseTools.nixBuild {
      name = "dysnomia";
      version = builtins.readFile ./version;
      src = jobs.tarball;
        
      preConfigure = stdenv.lib.optionalString enableEjabberdDump "export PATH=$PATH:${ejabberd}/sbin";

      configureFlags = [
        (if enableApacheWebApplication then "--with-apache" else "--without-apache")
        (if enableAxis2WebService then "--with-axis2" else "--without-axis2")
        (if enableEjabberdDump then "--with-ejabberd" else "--without-ejabberd")
        (if enableMySQLDatabase then "--with-mysql" else "--without-mysql")
        (if enablePostgreSQLDatabase then "--with-postgresql" else "--without-postgresql")
        (if enableMongoDatabase then "--with-mongodb" else "--without-mongodb")
        (if enableTomcatWebApplication then "--with-tomcat=${catalinaBaseDir}" else "--without-tomcat")
        (if enableSubversionRepository then "--with-subversion" else "--without-subversion")
        "--with-job-template=${jobTemplate}"
      ];
        
      buildInputs = [ getopt ]
        ++ stdenv.lib.optional enableEjabberdDump ejabberd
        ++ stdenv.lib.optional enableMySQLDatabase mysql
        ++ stdenv.lib.optional enablePostgreSQLDatabase postgresql
        ++ stdenv.lib.optional enableMongoDatabase mongodb
        ++ stdenv.lib.optional enableSubversionRepository subversion;
    };
  
  jobs = rec {
    tarball = pkgs.releaseTools.sourceTarball {
      name = "dysnomia-tarball";
      version = builtins.readFile ./version;
      src = dysnomia;
      inherit officialRelease;

      buildInputs = [ pkgs.getopt ];
    };

    build = pkgs.lib.genAttrs systems (system: 
      buildFun {
        inherit system;
      }
    );
      
    tests = 
      let
        dysnomia = buildFun {
          system = builtins.currentSystem;
          inherit tarball;
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
      {
        frontend = import ./tests/frontend.nix {
          inherit nixpkgs buildFun;
        };
        
        install = import ./tests/install.nix {
          inherit nixpkgs buildFun;
        };
        
        processes_systemd = import ./tests/processes-systemd.nix {
          inherit nixpkgs buildFun;
        };
        
        processes_direct = import ./tests/processes-direct.nix {
          inherit nixpkgs buildFun;
        };
      };
  };
in
jobs
