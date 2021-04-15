{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" "x86_64-darwin" "x86_64-freebsd" "x86_64-cygwin" ]
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
      {
        modules = {
          apache-webapplication = import ./tests/apache-webapplication.nix {
            inherit nixpkgs tarball buildFun;
            enableState = false;
          };

          apache-webapplication-with-state = import ./tests/apache-webapplication.nix {
            inherit nixpkgs tarball buildFun;
            enableState = true;
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

          nginx-webapplication = import ./tests/nginx-webapplication.nix {
            inherit nixpkgs tarball buildFun;
            enableState = false;
          };

          nginx-webapplication-with-state = import ./tests/nginx-webapplication.nix {
            inherit nixpkgs tarball buildFun;
            enableState = true;
          };

          influx-database = import ./tests/influx-database.nix {
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

          process = import ./tests/process.nix {
            inherit nixpkgs tarball buildFun;
          };

          wrapper = import ./tests/wrapper.nix {
            inherit nixpkgs tarball buildFun;
          };

          sysvinit-script = import ./tests/sysvinit-script.nix {
            inherit nixpkgs tarball buildFun;
          };

          systemd-unit = import ./tests/systemd-unit.nix {
            inherit nixpkgs tarball buildFun;
          };

          supervisord-program = import ./tests/supervisord-program.nix {
            inherit nixpkgs tarball buildFun;
          };

          s6-rc-service = import ./tests/s6-rc-service.nix {
            inherit nixpkgs tarball buildFun;
          };

          docker-container = import ./tests/docker-container.nix {
            inherit nixpkgs tarball buildFun;
          };

          xinetd-service = import ./tests/xinetd-service.nix {
            inherit nixpkgs tarball buildFun;
          };
        };

        snapshots = import ./tests/snapshots.nix {
          inherit nixpkgs tarball buildFun;
        };

        containers = import ./tests/containers.nix {
          inherit nixpkgs tarball buildFun;
        };

        users = import ./tests/users.nix {
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
        tests.users
      ];
      meta.description = "Release-critical builds";
    };
  };
in
jobs
