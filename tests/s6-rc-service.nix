{ buildFun,
  makeTest,
  pkgs,
  stdenv,
  tarball
}:

let
  dysnomia = buildFun {
    inherit pkgs tarball;
    enableS6RCService = true;
  };

  s6-rc-service = import ./deployment/s6-rc-service.nix {
    inherit (pkgs) stdenv writeTextFile coreutils execline;
  };
in
makeTest {
  name = "s6-rc-service";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      systemd.services.s6-svscan = {
        description = "s6-svscan service";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        preStart = ''
          mkdir -p /var/run/service
        '';
        serviceConfig = {
          ExecStart = "${pkgs.s6}/bin/s6-svscan /var/run/service";
        };
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_process_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${s6-rc-service}/bin/loop | grep -v grep)" != "" ]'
          )


      def check_process_not_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${s6-rc-service}/bin/loop | grep -v grep)" = "" ]'
          )


      start_all()

      machine.wait_for_job("s6-svscan")

      # Test supervisord-program module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped.

      machine.succeed(
          "dysnomia --type s6-rc-service --operation activate --component ${s6-rc-service} --environment"
      )
      check_process_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type s6-rc-service --operation activate --component ${s6-rc-service} --environment"
      )
      check_process_running()

      # Deactivate the process.
      machine.succeed(
          "dysnomia --type s6-rc-service --operation deactivate --component ${s6-rc-service} --environment"
      )
      check_process_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type s6-rc-service --operation deactivate --component ${s6-rc-service} --environment"
      )
      check_process_not_running()
    '';
}
