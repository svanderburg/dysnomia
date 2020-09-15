{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    jobTemplate = "systemd";
    enableLegacy = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  wrapper = import ./deployment/wrapper.nix {
    inherit stdenv;
  };

  wrapper_unprivileged = import ./deployment/wrapper-unprivileged.nix {
    inherit stdenv;
  };

  process = import ./deployment/process.nix {
    inherit stdenv;
  };

  process_unprivileged = import ./deployment/process-unprivileged.nix {
    inherit stdenv;
  };

  process_socketactivation = import ./deployment/process-socketactivation.nix {
    inherit stdenv;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      environment.systemPackages = [ dysnomia pkgs.netcat ];

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
      def check_wrapper_running():
          machine.succeed('sleep 5; [ "$(cat /tmp/wrapper.state)" = "wrapper active" ]')
          machine.succeed('[ "$(stat -c %U /tmp/wrapper.state)" = "root" ]')


      def check_wrapper_not_running():
          machine.succeed("sleep 5; [ ! -f /tmp/wrapper.state ]")


      def check_unprivileged_wrapper_running():
          machine.succeed('sleep 5; [ "$(cat /tmp/wrapper.state)" = "wrapper active" ]')
          machine.succeed('[ "$(stat -c %U /tmp/wrapper.state)" = "unprivileged" ]')


      def check_unprivileged_wrapper_not_running():
          machine.succeed("sleep 5; [ ! -f /tmp/wrapper.state ]")


      def check_process_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(systemctl status disnix-$(basename ${process}) | grep "Active: active")" != "" ]'
          )
          machine.succeed(
              '[ "$(ps aux | grep ${process}/bin/loop | grep -v grep | grep root)" != "" ]'
          )


      def check_process_not_running():
          machine.succeed("sleep 5")
          machine.fail(
              "systemctl status disnix-$(basename ${process})"
          )


      def check_unprivileged_process_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(systemctl status disnix-$(basename ${process_unprivileged}) | grep "Active: active")" != "" ]'
          )
          machine.succeed(
              '[ "$(ps aux | grep ${process_unprivileged}/bin/loop | grep -v grep | grep unprivileged)" != "" ]'
          )


      def check_unprivileged_process_not_running():
          machine.succeed("sleep 5")
          machine.fail(
              "systemctl status disnix-$(basename ${process_unprivileged})"
          )


      start_all()

      # Check if Dysnomia systemd target exists. It should exist, or the
      # remaining tests will not work reliably.
      machine.succeed("[ -f /etc/systemd-mutable/system/dysnomia.target ]")

      # Test wrapper module. Here we invoke the wrapper
      # of a certain service. On activation it writes a state file in
      # the temp folder.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type wrapper --operation activate --component ${wrapper} --environment"
      )
      check_wrapper_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type wrapper --operation activate --component ${wrapper} --environment"
      )
      check_wrapper_running()

      # Test wrapper module. Here we invoke the lock
      # operation of a certain service. It should write a lock file
      # into the temp dir and it should be owned by root.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type wrapper --operation lock --component ${wrapper} --environment"
      )
      machine.succeed('[ "$(stat -c %U /tmp/wrapper.lock)" = "root" ]')

      # Test wrapper module. Here we invoke the unlock
      # operation of a certain service. The lock file should be removed.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type wrapper --operation unlock --component ${wrapper} --environment"
      )
      machine.succeed("[ ! -f /tmp/wrapper.lock ]")

      # Deactivate the wrapper script. We also check whether the file created
      # on activation is owned by root.
      # This test should succeed.
      machine.succeed(
          "dysnomia --type wrapper --operation deactivate --component ${wrapper} --environment"
      )
      check_wrapper_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type wrapper --operation deactivate --component ${wrapper} --environment"
      )
      check_wrapper_not_running()

      # Test wrapper module. Here we invoke the wrapper
      # of a certain service. On activation it writes a state file in
      # the temp folder.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type wrapper --operation activate --component ${wrapper_unprivileged} --environment"
      )
      check_unprivileged_wrapper_running()

      # Activate again. This test should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type wrapper --operation activate --component ${wrapper_unprivileged} --environment"
      )
      check_unprivileged_wrapper_running()

      # Test wrapper module. Here we invoke the lock
      # operation of a certain service. It should write a lock file
      # into the temp dir and it should be owned by an unprivileged user.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type wrapper --operation lock --component ${wrapper_unprivileged} --environment"
      )
      machine.succeed('[ "$(stat -c %U /tmp/wrapper.lock)" = "unprivileged" ]')

      # Test wrapper module. Here we invoke the unlock
      # operation of a certain service. The lock file should be removed.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type wrapper --operation unlock --component ${wrapper_unprivileged} --environment"
      )
      machine.succeed("[ ! -f /tmp/wrapper.lock ]")

      # Deactivate the wrapper script. We also check whether the file created
      # on activation is owned by the unprivileged user.
      # This test should succeed.
      machine.succeed(
          "dysnomia --type wrapper --operation deactivate --component ${wrapper_unprivileged} --environment"
      )
      check_unprivileged_wrapper_not_running()

      # Deactivate again. This test should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type wrapper --operation deactivate --component ${wrapper_unprivileged} --environment"
      )
      check_unprivileged_wrapper_not_running()

      # Test process module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as root.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type process --operation activate --component ${process} --environment"
      )
      check_process_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type process --operation activate --component ${process} --environment"
      )
      check_process_running()

      # Deactivate the process
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${process} --environment"
      )
      check_process_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${process} --environment"
      )
      check_process_not_running()

      # Test process module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as an uprivileged user.
      # This test should succeed.

      machine.succeed(
          "dysnomia --type process --operation activate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_running()

      # Activate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          "dysnomia --type process --operation activate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_running()

      # Wreck the service and activate again. This test should succeed as the operation is idempotent.
      serviceName = "disnix-$(basename ${process_unprivileged}).service"

      machine.succeed(
          "systemctl stop {}".format(serviceName)
      )  # We deliberately stop the service manually
      machine.succeed(
          "rm /etc/systemd-mutable/system/dysnomia.target.wants/{}".format(serviceName)
      )  # We, by accident, remove the unit from the wants/ directory

      machine.succeed(
          "dysnomia --type process --operation activate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_running()

      # Deactivate the process
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_not_running()

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_not_running()

      # Socket activation test. We activate the process, but it should
      # only run if we attempt to connect to its corresponding socket. After we
      # have deactivated the service, it should both be terminated and the
      # socket should have disappeared.

      machine.succeed(
          "dysnomia --type process --operation activate --component ${process_socketactivation} --environment"
      )
      machine.succeed("sleep 5")
      machine.fail(
          "ps aux | grep ${process_socketactivation} | grep -v grep"
      )
      machine.succeed("nc -z -n -v 127.0.0.1 5123")
      machine.succeed(
          "ps aux | grep ${process_socketactivation} | grep -v grep"
      )

      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${process_socketactivation} --environment"
      )
      machine.succeed("sleep 5")
      machine.fail(
          "ps aux | grep ${process_socketactivation} | grep -v grep"
      )
      machine.fail("nc -z -n -v 127.0.0.1 5123")
    '';
}
