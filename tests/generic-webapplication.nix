{ nixpkgs, tarball, buildFun, dysnomiaParameters, machineConfig, unitName, enableState, type }:

let
  dysnomia = buildFun ({
    pkgs = import nixpkgs {};
    inherit tarball;
  } // dysnomiaParameters);
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  generic_webapplication = import ./deployment/generic-webapplication.nix {
    inherit stdenv lib enableState;
  };
in
makeTest {
  nodes = {
    machine = {
      imports = [ machineConfig ];
      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_connection():
          machine.succeed("curl --fail http://localhost/test")


      def check_no_connection():
          machine.fail("curl --fail http://localhost/test")


      webappSettings = "documentRoot=/var/www"

      start_all()

      # Test the generic web application script. Here, we activate a small
      # static HTML website in the document root of the web server, then we
      # check whether it is available. Finally, we deactivate it again
      # and see whether is has become unavailable.
      # This test should succeed.

      machine.wait_for_unit("${unitName}")
      machine.succeed(
          webappSettings
          + " dysnomia --type ${type} --operation activate --component ${generic_webapplication} --environment"
      )
      check_connection()

      # Activate again. This should succeed as the operation is idempotent
      machine.succeed(
          webappSettings
          + " dysnomia --type ${type} --operation activate --component ${generic_webapplication} --environment"
      )
      check_connection()

      # Deactivate the web application
      machine.succeed(
          webappSettings
          + " dysnomia --type ${type} --operation deactivate --component ${generic_webapplication} --environment"
      )
      check_no_connection()

      # Deactivate again. This should succeed as the operation is idempotent
      machine.succeed(
          webappSettings
          + " dysnomia --type ${type} --operation deactivate --component ${generic_webapplication} --environment"
      )
      check_no_connection()
    '';
}
