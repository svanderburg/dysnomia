{ nixpkgs ? /etc/nixos/nixpkgs }:

let
  jobs = rec {
    tarball =
      { disnix_activation_scripts_nixos ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      }:

      with import nixpkgs {};

      releaseTools.sourceTarball {
        name = "disnix-activation-scripts-nixos-tarball";
        version = builtins.readFile ./version;
        src = disnix_activation_scripts_nixos;
        inherit officialRelease;

        buildInputs = [ ];
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      with import nixpkgs { inherit system; };

      releaseTools.nixBuild {
        name = "disnix-activation-scripts-nixos";
        src = tarball;

        buildInputs = [ ];
      };      
  };
in jobs
