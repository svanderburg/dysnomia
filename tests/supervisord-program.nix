{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableSupervisordProgram = true;
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };
with pkgs;

let
  supervisord-program = import ./deployment/supervisord-program.nix {
    inherit (pkgs) stdenv coreutils;
  };

  supervisordConf = pkgs.writeTextFile {
    name = "supervisord.conf";
    text = ''
      [supervisord]

      [include]
      files=conf.d/*

      [inet_http_server]
      port = 127.0.0.1:9001

      [rpcinterface:supervisor]
      supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
    '';
  };
in
makeTest {
  name = "supervisord-program";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      systemd.services.supervisord = {
        description = "Supervisord service";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        preStart = ''
          mkdir -p /var/lib/supervisord/conf.d
          cp ${supervisordConf} /var/lib/supervisord/supervisord.conf
        '';
        serviceConfig = {
          ExecStart = "${pkgs.python3Packages.supervisor}/bin/supervisord -n -c /var/lib/supervisord/supervisord.conf";
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
              '[ "$(ps aux | grep ${supervisord-program}/bin/loop | grep -v grep)" != "" ]'
          )


      def check_process_not_running():
          machine.succeed("sleep 5")
          machine.succeed(
              '[ "$(ps aux | grep ${supervisord-program}/bin/loop | grep -v grep)" = "" ]'
          )


      start_all()

      machine.wait_for_job("supervisord")

      # Test supervisord-program module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped.

      machine.succeed(
          "dysnomia --type supervisord-program --operation activate --component ${supervisord-program} --environment"
      )
      check_process_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type supervisord-program --operation activate --component ${supervisord-program} --environment"
      )
      check_process_running()

      # Deactivate the process.
      machine.succeed(
          "dysnomia --type supervisord-program --operation deactivate --component ${supervisord-program} --environment"
      )
      check_process_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type supervisord-program --operation deactivate --component ${supervisord-program} --environment"
      )
      check_process_not_running()
    '';
}
