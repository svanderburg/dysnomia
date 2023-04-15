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
      let
        testing = import (nixpkgs + "/nixos/lib/testing-python.nix") {
          inherit pkgs;
          system = builtins.currentSystem;
        };

        callPackage = pkgs.lib.callPackageWith (pkgs // {
          inherit buildFun;
          inherit (jobs) tarball;
          inherit (testing) makeTest;
        });
      in
      {
        modules = {
          apache-webapplication = callPackage ./tests/apache-webapplication.nix {
            enableState = false;
          };

          apache-webapplication-with-state = callPackage ./tests/apache-webapplication.nix {
            enableState = true;
          };

          echo = callPackage ./tests/echo.nix {};

          mysql-database = callPackage ./tests/mysql-database.nix {};

          postgresql-database = callPackage ./tests/postgresql-database.nix {};

          mongo-database = callPackage ./tests/mongo-database.nix {};

          nginx-webapplication = callPackage ./tests/nginx-webapplication.nix {
            enableState = false;
          };

          nginx-webapplication-with-state = callPackage ./tests/nginx-webapplication.nix {
            enableState = true;
          };

          influx-database = callPackage ./tests/influx-database.nix {};

          tomcat-webapplication = callPackage ./tests/tomcat-webapplication.nix {};

          axis2-webservice = callPackage ./tests/axis2-webservice.nix {};

          # Fails with command `curl --fail --user 'newuser@localhost:newuser' http://localhost:5280/admin` unexpectedly succeeded.
          # Looks like it's flaky also because I already got another error message.
          # ejabberd-dump = callPackage ./tests/ejabberd-dump.nix {};

          fileset = callPackage ./tests/fileset.nix {};

          subversion-repository = callPackage ./tests/subversion-repository.nix {};

          nixos-configuration = callPackage ./tests/nixos-configuration.nix {};

          processes_systemd = callPackage ./tests/processes-systemd.nix {};

          processes_direct = callPackage ./tests/processes-direct.nix {};

          process = callPackage ./tests/process.nix {};

          wrapper = callPackage ./tests/wrapper.nix {};

          sysvinit-script = callPackage ./tests/sysvinit-script.nix {};

          systemd-unit = callPackage ./tests/systemd-unit.nix {};

          supervisord-program = callPackage ./tests/supervisord-program.nix {};

          s6-rc-service = callPackage ./tests/s6-rc-service.nix {};

          docker-container = callPackage ./tests/docker-container.nix {};

          # Fails with command `netstat -n --udp --listen | grep ':69'` failed (exit code 1)
          # but only when running the whole test suite.
          # xinetd-service = callPackage ./tests/xinetd-service.nix {};
        };

        snapshots = callPackage ./tests/snapshots.nix {};

        containers = callPackage ./tests/containers.nix {};

        users = callPackage ./tests/users.nix {};
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
