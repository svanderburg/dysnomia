{config, lib, pkgs, ...}:

with lib;
{
  # Minimal container config, as written in the nixos-container script
  boot.isContainer = true;
  networking.hostName = mkDefault "test";
  networking.useDHCP = false;

  # Run a simple TCP echo server
  services.xinetd = {
    enable = true;
    # This ugly hack is necessary because the NixOS service does not support
    # INTERNAL services
    extraDefaults = ''
      }

      service echo
      {
        protocol = tcp
        type = INTERNAL
        socket_type = stream
        wait = no
    '';
  };

  # Open the necessary port
  networking.firewall.allowedTCPPorts = [ 7 ];

  # Silence the warning
  system.stateVersion = "22.11";
}
