{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableDockerContainer = true;
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };
with pkgs;

let
  docker-container = import ./deployment/docker-container {
    inherit (pkgs) stdenv dockerTools nginx;
  };
in
makeTest {
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
      startAll;

      # Test the docker-container module. Start nginx serving a static HTML page. See if we can retrieve it.
      $machine->mustSucceed("dysnomia --type docker-container --operation activate --component ${docker-container} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("curl --fail http://localhost");

      # Activate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type docker-container --operation activate --component ${docker-container} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("curl --fail http://localhost");

      # Deactivate the process. Check if the container is not running anymore, and the Docker image removed.
      $machine->mustSucceed("dysnomia --type docker-container --operation deactivate --component ${docker-container} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("curl --fail http://localhost");
      my $result = $machine->mustSucceed("docker images | wc -l");

      if($result == 1) {
          print "We have no Docker images remaining!\n";
      } else {
          die("We have still have images left. Number of lines: $result");
      }

      # Deactivate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type docker-container --operation deactivate --component ${docker-container} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("curl --fail http://localhost");
    '';
}
