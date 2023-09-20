{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
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
in
makeTest {
  name = "tomcat-webapplication";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.tomcat.enable = true;
      services.tomcat.package = pkgs.tomcat9;
      users.users.tomcat.group = "tomcat";

      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      def check_app_available():
          machine.wait_for_file("/var/tomcat/webapps/tomcat-webapplication")
          machine.succeed("curl --fail http://localhost:8080/tomcat-webapplication")


      def check_app_unavailable():
          machine.succeed(
              "while [ -e /var/tomcat/webapps/tomcat-webapplication ]; do echo 'Waiting to undeploy' >&2; sleep 1; done"
          )
          machine.fail("curl --fail http://localhost:8080/tomcat-webapplication")


      start_all()

      # Test Tomcat web application script. Deploys a tomcat web
      # application, verifies whether it can be accessed and then
      # undeploys it again and checks whether it becomes inaccessible.
      # This test should succeed.

      machine.wait_for_unit("tomcat")

      machine.succeed(
          "dysnomia --type tomcat-webapplication --operation activate --component ${tomcat_webapplication} --environment"
      )
      check_app_available()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type tomcat-webapplication --operation activate --component ${tomcat_webapplication} --environment"
      )
      check_app_available()

      machine.succeed(
          "dysnomia --type tomcat-webapplication --operation deactivate --component ${tomcat_webapplication} --environment"
      )
      check_app_unavailable()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type tomcat-webapplication --operation deactivate --component ${tomcat_webapplication} --environment"
      )
      check_app_unavailable()
    '';
}
