{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableXinetdService = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  xinetd-service = import ./deployment/xinetd-service.nix {
    inherit (pkgs) stdenv inetutils;
  };

  xinetdConf = pkgs.writeTextFile {
    name = "xinetd.conf";
    text = ''
      includedir /var/lib/xinetd/xinetd.d
    '';
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      systemd.services.xinetd = {
        description = "xinetd server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig.ExecStart = "${pkgs.xinetd}/bin/xinetd -dontfork -f ${xinetdConf}";
      };

      environment.systemPackages = [ dysnomia pkgs.inetutils ];
    };
  };

  testScript =
    ''
      def check_service_running():
          machine.succeed("netstat -n --udp --listen | grep ':69'")
          machine.succeed("echo 'get /var/hello.txt' | tftp 127.0.0.1")
          machine.succeed("grep 'hello' hello.txt")
          machine.succeed("rm hello.txt")


      def check_service_not_running():
          machine.fail("netstat -n --udp --listen | grep ':69'")


      start_all()

      machine.wait_for_unit("xinetd")

      # Test xinetd-service module that deploys a TFTP service.
      # We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped.

      machine.succeed("echo hello > /var/hello.txt")

      machine.succeed(
          "dysnomia --type xinetd-service --operation activate --component ${xinetd-service} --environment"
      )
      check_service_running()

      # Activate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type xinetd-service --operation activate --component ${xinetd-service} --environment"
      )
      check_service_running()

      # Deactivate the process.
      machine.succeed(
          "dysnomia --type xinetd-service --operation deactivate --component ${xinetd-service} --environment"
      )
      check_service_not_running()

      # Deactivate again. This operation should succeed as it is idempotent.
      machine.succeed(
          "dysnomia --type xinetd-service --operation deactivate --component ${xinetd-service} --environment"
      )
      check_service_not_running()
    '';
}
