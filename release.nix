{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, dysnomia ? { outPath = ./.; rev = 1234; }
, officialRelease ? false
}:

let
  pkgs = import nixpkgs {};

  buildFun = import ./build.nix;

  jobs = rec {
    tarball = pkgs.releaseTools.sourceTarball {
      name = "dysnomia-tarball";
      version = builtins.readFile ./version;
      src = dysnomia;
      inherit officialRelease;

      buildInputs = [ pkgs.getopt pkgs.help2man ];
    };

    build = pkgs.lib.genAttrs systems (system:
      buildFun {
        inherit tarball;
        pkgs = import nixpkgs { inherit system; };
      }
    );

    tests =
      let
        dysnomia = buildFun {
          pkgs = import nixpkgs {};
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
        modules = {
          apache-webapplication = import ./tests/apache-webapplication.nix {
            inherit nixpkgs tarball buildFun;
          };

          apache-webapplication-with-state = import ./tests/apache-webapplication-with-state.nix {
            inherit nixpkgs tarball buildFun;
          };

          echo = import ./tests/echo.nix {
            inherit nixpkgs tarball buildFun;
          };

          mysql-database = import ./tests/mysql-database.nix {
            inherit nixpkgs tarball buildFun;
          };

          postgresql-database = import ./tests/postgresql-database.nix {
            inherit nixpkgs tarball buildFun;
          };

          mongo-database = import ./tests/mongo-database.nix {
            inherit nixpkgs tarball buildFun;
          };

          tomcat-webapplication = import ./tests/tomcat-webapplication.nix {
            inherit nixpkgs tarball buildFun;
          };

          axis2-webservice = import ./tests/axis2-webservice.nix {
            inherit nixpkgs tarball buildFun;
          };

          ejabberd-dump = import ./tests/ejabberd-dump.nix {
            inherit nixpkgs tarball buildFun;
          };

          fileset = import ./tests/fileset.nix {
            inherit nixpkgs tarball buildFun;
          };

          subversion-repository = import ./tests/subversion-repository.nix {
            inherit nixpkgs tarball buildFun;
          };

          nixos-configuration = import ./tests/nixos-configuration.nix {
            inherit nixpkgs tarball buildFun;
          };

          processes_systemd = import ./tests/processes-systemd.nix {
            inherit nixpkgs tarball buildFun;
          };

          processes_direct = import ./tests/processes-direct.nix {
            inherit nixpkgs tarball buildFun;
          };
        };

        snapshots = import ./tests/snapshots.nix {
          inherit nixpkgs tarball buildFun;
        };

        containers = import ./tests/containers.nix {
          inherit nixpkgs tarball buildFun;
        };
      };

    release = pkgs.releaseTools.aggregate {
      name = "dysnomia-${tarball.version}";
      constituents = [
        tarball
      ]
      ++ map (system: builtins.getAttr system build) systems
      ++ map (module: builtins.getAttr module tests.modules) (builtins.attrNames tests.modules)
      ++ [
        tests.snapshots
        tests.containers
      ];
      meta.description = "Release-critical builds";
    };
  };
in
jobs
