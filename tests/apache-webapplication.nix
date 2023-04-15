{
  buildFun,
  enableState,
  lib,
  makeTest,
  pkgs,
  stdenv,
  system,
  tarball
}:

import ./generic-webapplication.nix {
  inherit pkgs tarball buildFun stdenv lib makeTest enableState system;

  name = "apache-webapplication";
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
