{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableSystemdUnit = true;
  };

  pkgs = import nixpkgs {};
in
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };
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
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      environment.systemPackages = [ dysnomia ];

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
      startAll;

      # Check if Dysnomia systemd target exists. It should exist, or the
      # remaining tests will not work reliably.
      $machine->mustSucceed("[ -f /etc/systemd-mutable/system/dysnomia.target ]");

      # Test the systemd-unit module. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as root.

      $machine->mustSucceed("dysnomia --type systemd-unit --operation activate --component ${systemd-unit} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(systemctl status process.service | grep \"Active: active\")\" != \"\" ]");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${systemd-unit}/bin/loop | grep -v grep | grep root)\" != \"\" ]");

      # Activate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type systemd-unit --operation activate --component ${systemd-unit} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(systemctl status process.service | grep \"Active: active\")\" != \"\" ]");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${systemd-unit}/bin/loop | grep -v grep | grep root)\" != \"\" ]");

      # Deactivate the process
      $machine->mustSucceed("dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("systemctl status process.service");

      # Deactivate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("systemctl status process.service");

      # Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as an uprivileged user.

      $machine->mustSucceed("dysnomia --type systemd-unit --operation activate --component ${systemd-unit-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(systemctl status process-unprivileged.service | grep \"Active: active\")\" != \"\" ]");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${systemd-unit-unprivileged}/bin/loop | grep -v grep | grep unprivi)\" != \"\" ]");

      # Activate again. This test should succeed as the operation is idempotent.
      $machine->mustSucceed("dysnomia --type systemd-unit --operation activate --component ${systemd-unit-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(systemctl status process-unprivileged.service | grep \"Active: active\")\" != \"\" ]");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${systemd-unit-unprivileged}/bin/loop | grep -v grep | grep unprivi)\" != \"\" ]");

      # Wreck the service and activate again. This test should succeed as the operation is idempotent.
      my $serviceName = "process-unprivileged.service";

      $machine->mustSucceed("systemctl stop $serviceName"); # We deliberately stop the service manually
      $machine->mustSucceed("rm /etc/systemd-mutable/system/dysnomia.target.wants/$serviceName"); # We, by accident, remove the unit from the wants/ directory

      $machine->mustSucceed("dysnomia --type systemd-unit --operation activate --component ${systemd-unit-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(systemctl status process-unprivileged.service | grep \"Active: active\")\" != \"\" ]");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${systemd-unit-unprivileged}/bin/loop | grep -v grep | grep unprivi)\" != \"\" ]");

      # Deactivate the process
      $machine->mustSucceed("dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("systemctl status process-unprivileged.service");

      # Deactivate again. This test should succeed as the operation is idempotent.
      $machine->mustSucceed("dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit-unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("systemctl status process-unprivileged.service");

      # Socket activation test. We activate the process, but it should
      # only run if we attempt to connect to its corresponding socket. After we
      # have deactivated the service, it should both be terminated and the
      # socket should have disappeared.

      $machine->mustSucceed("dysnomia --type systemd-unit --operation activate --component ${systemd-unit-socketactivation} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("ps aux | grep ${systemd-unit-socketactivation} | grep -v grep");
      $machine->mustSucceed("nc -z -n -v 127.0.0.1 5123");
      $machine->mustSucceed("ps aux | grep ${systemd-unit-socketactivation} | grep -v grep");
      $machine->mustSucceed("dysnomia --type systemd-unit --operation deactivate --component ${systemd-unit-socketactivation} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustFail("ps aux | grep ${systemd-unit-socketactivation} | grep -v grep");
      $machine->mustFail("nc -z -n -v 127.0.0.1 5123");
    '';
}
