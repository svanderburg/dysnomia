{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
, pkgs ? import nixpkgs { inherit system; }
, dysnomia ? { outPath = ./.; rev = 1234; }
, officialRelease ? false
}:

let
  buildFun = import ./build.nix;

  testing = import (nixpkgs + "/nixos/lib/testing-python.nix") { inherit pkgs system; };

  callPackage = pkgs.lib.callPackageWith (pkgs // {
    inherit buildFun;
    inherit (jobs) tarball;
    inherit (testing) makeTest;
  });

  jobs = rec {
    tarball = pkgs.releaseTools.sourceTarball {
      name = "dysnomia-tarball";
      version = builtins.readFile ./version;
      src = dysnomia;
      inherit officialRelease;

      buildInputs = [ pkgs.getopt pkgs.help2man ];
    };

    build = buildFun {
      inherit tarball pkgs;
    };

    tests =
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

          ejabberd-dump = callPackage ./tests/ejabberd-dump.nix {};

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

          xinetd-service = callPackage ./tests/xinetd-service.nix {};
        };

        snapshots = callPackage ./tests/snapshots.nix {};

        containers = callPackage ./tests/containers.nix {};

        users = callPackage ./tests/users.nix {};
      };

    release = pkgs.releaseTools.aggregate {
      name = "dysnomia-${tarball.version}";
      constituents = [
        tarball
        build
      ]
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
