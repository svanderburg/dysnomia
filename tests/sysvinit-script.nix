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
  sysvinit-script = import ./deployment/sysvinit-script.nix {
    inherit (pkgs) stdenv daemon coreutils;
  };

  sysvinit-script-unprivileged = import ./deployment/sysvinit-script-unprivileged.nix {
    inherit (pkgs) stdenv daemon coreutils;
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

      # Test sysvinit-script module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if root owns the process.

      $machine->mustSucceed("dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script}/bin/loop | grep -v grep | grep root)\" != \"\" ]");

      # Activate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script}/bin/loop | grep -v grep | grep root)\" != \"\" ]");

      # Deactivate the process.
      $machine->mustSucceed("dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script}/bin/loop | grep -v grep | grep root)\" = \"\" ]");

      # Deactivate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script}/bin/loop | grep -v grep | grep root)\" = \"\" ]");

      # Test sysvinit-script module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if an uprivileged user owns the process.

      $machine->mustSucceed("dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script-unprivileged}/bin/loop | grep -v grep | grep unprivi)\" != \"\" ]");

      # Activate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script-unprivileged}/bin/loop | grep -v grep | grep unprivi)\" != \"\" ]");

      # Deactivate the process.
      $machine->mustSucceed("dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script-unprivileged}/bin/loop | grep -v grep | grep unprivi)\" = \"\" ]");

      # Deactivate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${sysvinit-script-unprivileged}/bin/loop | grep -v grep | grep unprivi)\" = \"\" ]");
    '';
}
