{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableApacheWebApplication = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  apache_webapplication = import ./deployment/apache-webapplication.nix {
    inherit stdenv lib;
    enableState = true;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.httpd = {
        enable = true;
        adminAddr = "foo@bar.com";
        virtualHosts.localhost.documentRoot = "/var/www";
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


      apacheSettings = "documentRoot=/var/www"

      start_all()

      # Test Apache web application script. Here, we activate a small
      # static HTML website in the document root of Apache, then we
      # check whether it is available. Finally, we deactivate it again
      # and see whether is has become unavailable.
      # This test should succeed.

      machine.wait_for_unit("httpd")
      machine.succeed(
          apacheSettings
          + " dysnomia --type apache-webapplication --operation activate --component ${apache_webapplication} --environment"
      )
      machine.succeed("ls /var/www/test -l >&2")
      check_connection()

      # Activate again. This should succeed as the operation is idempotent
      machine.succeed(
          apacheSettings
          + " dysnomia --type apache-webapplication --operation activate --component ${apache_webapplication} --environment"
      )
      check_connection()

      # Deactivate the web application
      machine.succeed(
          apacheSettings
          + " dysnomia --type apache-webapplication --operation deactivate --component ${apache_webapplication} --environment"
      )
      check_no_connection()

      # Deactivate again. This should succeed as the operation is idempotent
      machine.succeed(
          apacheSettings
          + " dysnomia --type apache-webapplication --operation deactivate --component ${apache_webapplication} --environment"
      )
      check_no_connection()
    '';
}
