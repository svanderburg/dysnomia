{ buildFun,
  makeTest,
  pkgs,
  stdenv,
  tarball
}:

let
  dysnomia = buildFun {
    inherit pkgs tarball;
    jobTemplate = "direct";
  };

  sysvinit-script = import ./deployment/sysvinit-script.nix {
    inherit (pkgs) stdenv daemon coreutils;
  };

  sysvinit-script-unprivileged = import ./deployment/sysvinit-script-unprivileged.nix {
    inherit (pkgs) stdenv daemon coreutils;
  };
in
makeTest {
  name = "sysvinit-script";

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
          machine.succeed(
              '[ "$(ps aux | grep ${sysvinit-script}/bin/loop | grep -v grep | grep root)" != "" ]'
          )


      def check_process_not_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${sysvinit-script}/bin/loop | grep -v grep | grep root)" = "" ]'
          )


      def check_unprivileged_process_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${sysvinit-script-unprivileged}/bin/loop | grep -v grep | grep unprivi)" != "" ]'
          )


      def check_unprivileged_process_not_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${sysvinit-script-unprivileged}/bin/loop | grep -v grep | grep unprivi)" = "" ]'
          )


      start_all()

      # Test sysvinit-script module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if root owns the process.

      machine.succeed(
          "dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script} --environment"
      )
      check_process_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script} --environment"
      )
      check_process_running()

      # Deactivate the process.
      machine.succeed(
          "dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script} --environment"
      )
      check_process_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script} --environment"
      )
      check_process_not_running()

      # Test sysvinit-script module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if an uprivileged user owns the process.

      machine.succeed(
          "dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script-unprivileged} --environment"
      )
      check_unprivileged_process_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type sysvinit-script --operation activate --component ${sysvinit-script-unprivileged} --environment"
      )
      check_unprivileged_process_running()

      # Deactivate the process.
      machine.succeed(
          "dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script-unprivileged} --environment"
      )
      check_unprivileged_process_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type sysvinit-script --operation deactivate --component ${sysvinit-script-unprivileged} --environment"
      )
      check_unprivileged_process_not_running()
    '';
}
