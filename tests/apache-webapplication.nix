{ nixpkgs, tarball, buildFun, enableState }:

import ./generic-webapplication.nix {
  inherit nixpkgs tarball buildFun enableState;

  type = "apache-webapplication";
  unitName = "httpd";

  dysnomiaParameters = {
    enableApacheWebApplication = true;
  };

  machineConfig = {config, pkgs, ...}:

  {
    virtualisation.memorySize = 1024;
    virtualisation.diskSize = 4096;

    services.httpd = {
      enable = true;
      adminAddr = "foo@bar.com";
      virtualHosts.localhost.documentRoot = "/var/www";
    };
  };
}
