{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableSystemdUnit = true;
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };
with pkgs;

let
  systemd-unit = import ./deployment/systemd-unit.nix {
    inherit (pkgs) stdenv coreutils;
  };

  systemd-unit-unprivileged = import ./deployment/systemd-unit-unprivileged.nix {
    inherit (pkgs) stdenv coreutils;
  };

  systemd-unit-socketactivation = import ./deployment/systemd-unit-socketactivation.nix {
    inherit (pkgs) stdenv coreutils;
  };

  systemd-unit-timeractivation = import ./deployment/systemd-unit-timeractivation.nix {
    inherit (pkgs) stdenv coreutils hello;
  };
in
makeTest {
  name = "systemd-unit";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      environment.systemPackages = [ dysnomia ];

      boot.extraSystemdUnitPaths = [ "/etc/systemd-mutable/system" ];

      system.activationScripts.dysnomia = ''
        mkdir -p /etc/systemd-mutable/system
        if [ ! -f /etc/systemd-mutable/system/dysnomia.target ]
        then
            ( echo "[Unit]"
              echo "Description=Services that are activated and deactivated by Dysnomia"
              echo "After=final.target"
            ) > /etc/systemd-mutable/system/dysnomia.target
        fi
      '';
    };
  };

  testScript =
    ''
      def check_process_activated():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(systemctl status process.service | grep "Active: active")" != "" ]'
          )
          machine.succeed(
              '[ "$(ps aux | grep ${systemd-unit}/bin/loop | grep -v grep | grep root)" != "" ]'
          )


      def check_process_deactivated():
          machine.succeed("sleep 5")
          machine.fail("systemctl status process.service")


      def check_unprivileged_process_activated():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(systemctl status process-unprivileged.service | grep "Active: active")" != "" ]'
          )
          machine.succeed(
              '[ "$(ps aux | grep ${systemd-unit-unprivileged}/bin/loop | grep -v grep | grep unprivi)" != "" ]'
          )


      def check_unprivileged_process_deactivated():
          machine.succeed("sleep 5")
          machine.fail("systemctl status process-unprivileged.service")


      start_all()

      # Check if Dysnomia systemd target exists. It should exist, or the
      # remaining tests will not work reliably.
      machine.succeed("[ -f /etc/systemd-mutable/system/dysnomia.target ]")

      # Test the systemd-unit module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as root.

      machine.succeed(
          "dysnomia --type systemd-unit --operation activate --component ${systemd-unit} --environment"
      )
      check_process_activated()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type systemd-unit --operation activate --component ${systemd-unit} --environment"
      )
      check_process_activated()

      # Deactivate the process
      machine.succeed(
          "dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit} --environment"
      )
      check_process_deactivated()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit} --environment"
      )
      check_process_deactivated()

      # Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as an uprivileged user.

      machine.succeed(
          "dysnomia --type systemd-unit --operation activate --component ${systemd-unit-unprivileged} --environment"
      )
      check_unprivileged_process_activated()

      # Activate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          "dysnomia --type systemd-unit --operation activate --component ${systemd-unit-unprivileged} --environment"
      )
      check_unprivileged_process_activated()

      # Wreck the service and activate again. This test should succeed as the operation is idempotent.
      serviceName = "process-unprivileged.service"

      machine.succeed(
          "systemctl stop {}".format(serviceName)
      )  # We deliberately stop the service manually
      machine.succeed(
          "rm /etc/systemd-mutable/system/dysnomia.target.wants/{}".format(serviceName)
      )  # We, by accident, remove the unit from the wants/ directory

      machine.succeed(
          "dysnomia --type systemd-unit --operation activate --component ${systemd-unit-unprivileged} --environment"
      )
      check_unprivileged_process_activated()

      # Deactivate the process
      machine.succeed(
          "dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit-unprivileged} --environment"
      )
      check_unprivileged_process_deactivated()

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          "dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit-unprivileged} --environment"
      )
      check_unprivileged_process_deactivated()

      # Check if the user and group were deleted as well
      machine.fail("id -u unprivileged")
      machine.fail("getent unprivileged")

      # Socket activation test. We activate the process, but it should
      # only run if we attempt to connect to its corresponding socket. After we
      # have deactivated the service, it should both be terminated and the
      # socket should have disappeared.

      machine.succeed(
          "dysnomia --type systemd-unit --operation activate --component ${systemd-unit-socketactivation} --environment"
      )
      machine.succeed("sleep 5")
      machine.fail(
          "ps aux | grep ${systemd-unit-socketactivation} | grep -v grep"
      )
      machine.succeed("nc -z -n -v 127.0.0.1 5123")
      machine.succeed(
          "ps aux | grep ${systemd-unit-socketactivation} | grep -v grep"
      )

      machine.succeed(
          "dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit-socketactivation} --environment"
      )
      machine.succeed("sleep 5")
      machine.fail(
          "ps aux | grep ${systemd-unit-socketactivation} | grep -v grep"
      )
      machine.fail("nc -z -n -v 127.0.0.1 5123")

      machine.fail("systemctl status hello.service")
      machine.fail("systemctl status hello.socket")

      # Timer activation test.

      machine.succeed(
          "dysnomia --type systemd-unit --operation activate --component ${systemd-unit-timeractivation} --environment"
      )
      machine.succeed("sleep 20")
      machine.succeed('systemctl status hello.timer | grep -q "Active: active"')
      # machine.succeed('systemctl status hello.service | grep "Finished Hello."')

      machine.succeed(
          "dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit-timeractivation} --environment"
      )
      machine.succeed("sleep 5")

      machine.fail("systemctl status hello.service")
      machine.fail("systemctl status hello.timer")
    '';
}
