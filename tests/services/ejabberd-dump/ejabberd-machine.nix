{
  test = {pkgs, ...}:

  {
    services.ejabberd.enable = true;
    services.ejabberd.configFile = ./ejabberd.yml;

    networking.firewall.allowedTCPPorts = [ 5222 5280 ];

    environment.systemPackages = [
      pkgs.mc
    ];
  };
}
