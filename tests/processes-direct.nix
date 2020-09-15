{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    jobTemplate = "direct";
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
              '[ "$(ps aux | grep ${process}/bin/loop | grep -v grep | grep root)" != "" ]'
          )


      def check_process_not_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${process}/bin/loop | grep -v grep | grep root)" = "" ]'
          )


      def check_unprivileged_process_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${process_unprivileged}/bin/loop | grep -v grep | grep unprivileged)" != "" ]'
          )


      def check_unprivileged_process_not_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${process_unprivileged}/bin/loop | grep -v grep | grep unprivileged)" = "" ]'
          )


      start_all()

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
      # the temp folder. After a while we deactivate it and we check
      # if the state file is removed. We also check whether the file is owned
      # by an unprivileged user.
      # This test should succeed.

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

      # Deactivate the process.
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

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type process --operation activate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_running()

      # Deactivate the process.
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type process --operation deactivate --component ${process_unprivileged} --environment"
      )
      check_unprivileged_process_not_running()
    '';
}
