{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableNixosContainer = true;
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };
with pkgs;

let
  # Pre-evaluate the container derivation, otherwise the VM needs to do it and
  # there is no Internet connection in there
  sysEval = import "${nixpkgs}/nixos/lib/eval-config.nix";
  container = (sysEval {
    system = builtins.currentSystem;
    modules = [
      ./deployment/nixos-container/configuration.nix
    ];
  }).config.system.build.toplevel;

  component = symlinkJoin {
    name = "nixos-container-component";
    paths = [
      # This defines a simple container implementing the TCP echo protocol
      ./deployment/nixos-container
      # Parameters passed to nixos-container need to be created dynamically
      # because we have to provide a path to the pre-built derivation of the
      # container
      (runCommandLocal "test-container-createparams-cmd" {} ''
         mkdir $out

         cat >> $out/test-container-createparams << EOF
         --host-address
         10.235.0.1
         --local-address
         10.235.0.2
         --system-path
         ${container}
         EOF
       '').out
    ];
  };

  addr = "10.235.0.2";
in
makeTest {
  name = "dysnomia-nixos-container-test";
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 512;
      virtualisation.diskSize = 1024;
      boot.enableContainers = true;

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      # This pipeline will write "test" to stdout upon success
      testcmd = "echo \"test\" | nc -N ${addr} 7"

      def check_container_activated():
          machine.succeed("sleep 5")
          # Compare output to the expected string
          machine.succeed("test " + testcmd + " = \"test\"")


      def check_container_deactivated():
          machine.succeed("sleep 5")
          # Netcat fails with code 1 if the machine is inactive
          machine.fail(testcmd)


      # Activate the test container and verify that the TCP echo server is working
      machine.succeed(
          "dysnomia --type nixos-container --operation activate --component ${component} --environment"
      )
      check_container_activated()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type nixos-container --operation activate --component ${component} --environment"
      )
      check_container_activated()

      # Deactivate the process. Check if the container is not running anymore, and verify that it has been removed.
      machine.succeed(
          "dysnomia --type nixos-container --operation deactivate --component ${component} --environment"
      )
      check_container_deactivated()

      machine.succeed("test $(nixos-container list | wc -l) = 0")

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type nixos-container --operation deactivate --component ${component} --environment"
      )
      check_container_deactivated()
    '';
}
