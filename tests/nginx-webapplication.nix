{ nixpkgs, tarball, buildFun, enableState }:

import ./generic-webapplication.nix {
  inherit nixpkgs tarball buildFun enableState;

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
