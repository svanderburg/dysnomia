{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableSupervisordProgram = true;
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };
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
          ExecStart = "${pkgs.pythonPackages.supervisor}/bin/supervisord -n -c /var/lib/supervisord/supervisord.conf";
        };
      };

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      startAll;
      $machine->waitForJob("supervisord");

      # Test supervisord-program module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped.

      $machine->mustSucceed("dysnomia --type supervisord-program --operation activate --component ${supervisord-program} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${supervisord-program}/bin/loop | grep -v grep)\" != \"\" ]");

      # Activate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type supervisord-program --operation activate --component ${supervisord-program} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${supervisord-program}/bin/loop | grep -v grep)\" != \"\" ]");

      # Deactivate the process.
      $machine->mustSucceed("dysnomia --type supervisord-program --operation deactivate --component ${supervisord-program} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${supervisord-program}/bin/loop | grep -v grep)\" = \"\" ]");

      # Deactivate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type supervisord-program --operation deactivate --component ${supervisord-program} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${supervisord-program}/bin/loop | grep -v grep)\" = \"\" ]");
    '';
}
