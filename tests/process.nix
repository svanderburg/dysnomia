{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    jobTemplate = "direct";
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };
with pkgs;

let
  daemon = import ./deployment/daemon.nix {
    inherit (pkgs) stdenv daemon;
  };

  daemon-simple = import ./deployment/daemon-simple.nix {
    inherit (pkgs) stdenv daemon;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_process_running():
          machine.succeed("sleep 5")
          machine.succeed("[ -e /var/run/loop.pid ]")
          machine.succeed('[ "$(ps aux | grep /bin/loop | grep -v grep)" != "" ]')


      def check_process_not_running():
          machine.succeed("sleep 5")
          machine.succeed("[ ! -e /var/run/loop.pid ]")
          machine.succeed('[ "$(ps aux | grep /bin/loop | grep -v grep)" = "" ]')


      start_all()
    ''
    + stdenv.lib.concatMapStrings (pkg: ''
      # Test process module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped.

      machine.succeed(
          "dysnomia --type process --operation activate --component ${pkg} --environment"
      )
      check_process_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type process --operation activate --component ${pkg} --environment"
      )
      check_process_running()

      # Deactivate the process.
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${pkg} --environment"
      )
      check_process_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${pkg} --environment"
      )
      check_process_not_running()
    '') [ daemon daemon-simple ];
}
