{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableNginxWebApplication = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  nginx_webapplication = import ./deployment/apache-webapplication.nix {
    inherit stdenv lib;
  };

  documentRoot = "/var/www";
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.nginx = {
        enable = true;
        appendHttpConfig = ''
          server {
            listen localhost:80;
            root ${documentRoot};
          }
        '';
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_connection():
          machine.succeed("curl --fail http://localhost/test")


      def check_no_connection():
          machine.fail("curl --fail http://localhost/test")


      nginxSettings = "documentRoot=${documentRoot}"

      start_all()

      # Test Nginx web application script. Here, we activate a small
      # static HTML website in the document root of Nginx, then we
      # check whether it is available. Finally, we deactivate it again
      # and see whether is has become unavailable.
      # This test should succeed.

      machine.wait_for_unit("nginx")
      machine.succeed(
          nginxSettings
          + " dysnomia --type nginx-webapplication --operation activate --component ${nginx_webapplication} --environment"
      )
      check_connection()

      # Activate again. This should succeed as the operation is idempotent
      machine.succeed(
          nginxSettings
          + " dysnomia --type nginx-webapplication --operation activate --component ${nginx_webapplication} --environment"
      )
      check_connection()

      # Deactivate the web application
      machine.succeed(
          nginxSettings
          + " dysnomia --type nginx-webapplication --operation deactivate --component ${nginx_webapplication} --environment"
      )
      check_no_connection()

      # Deactivate again. This should succeed as the operation is idempotent
      machine.succeed(
          nginxSettings
          + " dysnomia --type nginx-webapplication --operation deactivate --component ${nginx_webapplication} --environment"
      )
      check_no_connection()
    '';
}
