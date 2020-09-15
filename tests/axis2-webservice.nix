{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableAxis2WebService = true;
    enableTomcatWebApplication = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  tomcat_webapplication = import ./deployment/tomcat-webapplication.nix {
    inherit stdenv jdk;
  };

  axis2_webservice = import ./deployment/axis2-webservice.nix {
    inherit stdenv jdk;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.tomcat.enable = true;
      services.tomcat.axis2.enable = true;

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_service_available():
          machine.succeed(
              "sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"
          )  # !!! We must wait a while to let it become active


      def check_service_unavailable():
          machine.fail(
              "sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"
          )  # !!! We must wait a while to let it become inactive


      start_all()

      machine.wait_for_unit("tomcat")
      machine.wait_for_file("/var/tomcat/webapps/axis2")

      # Test Axis2 web service script.

      machine.succeed(
          "dysnomia --type axis2-webservice --operation activate --component ${axis2_webservice} --environment"
      )
      check_service_available()

      # Activate again. This should succeed as the operation is idempotent
      machine.succeed(
          "dysnomia --type axis2-webservice --operation activate --component ${axis2_webservice} --environment"
      )
      check_service_available()

      machine.succeed(
          "dysnomia --type axis2-webservice --operation deactivate --component ${axis2_webservice} --environment"
      )
      check_service_unavailable()

      # Deactivate again. This should succeed as the operation is idempotent
      machine.succeed(
          "dysnomia --type axis2-webservice --operation deactivate --component ${axis2_webservice} --environment"
      )
      check_service_unavailable()
    '';
}
