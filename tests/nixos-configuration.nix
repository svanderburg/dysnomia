{ nixpkgs, buildFun }:

let
  dysnomia = buildFun {
    system = builtins.currentSystem;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

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
      startAll;
      
      # Test NixOS configuration activation script. We activate the current
      # NixOS configuration
      $machine->mustSucceed("disableNixOSSystemProfile=1 testNixOS=1 dysnomia --type nixos-configuration --operation activate --component /var/run/current-system --environment");
    '';
}
