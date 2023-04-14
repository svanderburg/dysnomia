{ buildFun,
  dysnomiaParameters,
  jdk,
  lib,
  machineConfig,
  makeTest,
  pkgs,
  stdenv,
  tarball,
  type,
}:

let
  dysnomia = buildFun ({
    inherit pkgs tarball;
  } // dysnomiaParameters);

  # Test services

  generic_webapplication = import ./deployment/generic-webapplication.nix {
    inherit stdenv lib;
    enableState = true;
  };
in
makeTest {
  name = "generic-webapplication-with-state";

  nodes = {
    machine = machineConfig;
  };

  testScript =
    ''
      def check_connection():
          machine.succeed("curl --fail http://localhost/test")


      def check_no_connection():
          machine.fail("curl --fail http://localhost/test")


      webappSettings = "documentRoot=/var/www"

      start_all()

      # Test generic web application script. Here, we activate a small
      # static HTML website in the document root of the web server, then we
      # check whether it is available. Finally, we deactivate it again
      # and see whether is has become unavailable.
      # This test should succeed.

      machine.wait_for_unit("httpd")
      machine.succeed(
          webappSettings
          + " dysnomia --type ${type} --operation activate --component ${generic_webapplication} --environment"
      )
      machine.succeed("ls /var/www/test -l >&2")
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
