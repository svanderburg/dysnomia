{ buildFun,
  enableState,
  lib,
  makeTest,
  pkgs,
  stdenv,
  system,
  tarball,
}:

import ./generic-webapplication.nix {
  inherit pkgs tarball buildFun stdenv lib makeTest enableState system;

  name = "nginx-webapplication";
  type = "nginx-webapplication";
  unitName = "nginx";

  dysnomiaParameters = {
    enableNginxWebApplication = true;
  };

  machineConfig = {config, pkgs, ...}:

  {
    virtualisation.memorySize = 1024;
    virtualisation.diskSize = 4096;

    services.nginx = {
      enable = true;
      appendHttpConfig = ''
        server {
          listen localhost:80;
          root /var/www;
        }
      '';
    };
  };
}
