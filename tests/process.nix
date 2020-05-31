{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    jobTemplate = "direct";
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };
with pkgs;

let
  daemon = import ./deployment/daemon.nix {
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
      startAll;

      # Test process module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped.

      $machine->mustSucceed("dysnomia --type process --operation activate --component ${daemon} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${daemon}/bin/loop | grep -v grep)\" != \"\" ]");

      # Activate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type process --operation activate --component ${daemon} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${daemon}/bin/loop | grep -v grep)\" != \"\" ]");

      # Deactivate the process.
      $machine->mustSucceed("dysnomia --type process --operation deactivate --component ${daemon} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${daemon}/bin/loop | grep -v grep)\" = \"\" ]");

      # Deactivate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type process --operation deactivate --component ${daemon} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${daemon}/bin/loop | grep -v grep)\" = \"\" ]");
    '';
}
