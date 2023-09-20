{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableDockerContainer = true;
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };
with pkgs;

let
  docker-container = import ./deployment/docker-container {
    inherit (pkgs) stdenv dockerTools buildEnv nginx;
  };
in
makeTest {
  name = "docker-container";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;
      virtualisation.docker.enable = true;

      environment.systemPackages = [ dysnomia pkgs.curl ];
    };
  };

  testScript =
    ''
      def check_container_activated():
          machine.succeed("sleep 5")
          machine.succeed("curl --fail http://localhost")


      def check_container_deactivated():
          machine.succeed("sleep 5")
          machine.fail("curl --fail http://localhost")


      start_all()

      # Test the docker-container module. Start nginx serving a static HTML page. See if we can retrieve it.
      machine.succeed(
          "dysnomia --type docker-container --operation activate --component ${docker-container} --environment"
      )
      check_container_activated()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type docker-container --operation activate --component ${docker-container} --environment"
      )
      check_container_activated()

      # Deactivate the process. Check if the container is not running anymore, and the Docker image removed.
      machine.succeed(
          "dysnomia --type docker-container --operation deactivate --component ${docker-container} --environment"
      )
      check_container_deactivated()

      result = machine.succeed("docker images | wc -l")

      if int(result) == 1:
          print("We have no Docker images remaining!")
      else:
          raise Exception(
              "We have still have images left. Number of lines: {}".format(result)
          )

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type docker-container --operation deactivate --component ${docker-container} --environment"
      )
      check_container_deactivated()
    '';
}
