{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    jobTemplate = "direct";
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  wrapper = import ./deployment/wrapper.nix {
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
      startAll;

      # Test wrapper module. Here we invoke the wrapper
      # of a certain service. On activation it writes a state file in
      # the temp folder.
      # This test should succeed.

      $machine->mustSucceed("dysnomia --type wrapper --operation activate --component ${wrapper} --environment");
      $machine->mustSucceed("sleep 5; [ \"\$(cat /tmp/wrapper.state)\" = \"wrapper active\" ]");

      # Activate again. This operation should succeed as it is idempotent.
      #$machine->mustSucceed("dysnomia --type wrapper --operation activate --component ${wrapper} --environment");
      #$machine->mustSucceed("sleep 5; [ \"\$(cat /tmp/wrapper.state)\" = \"wrapper active\" ]");

      # Test wrapper module. Here we invoke the lock
      # operation of a certain service. It should write a lock file
      # into the temp dir.
      $machine->mustSucceed("dysnomia --type wrapper --operation lock --component ${wrapper} --environment");

      # Test wrapper module. Here we invoke the unlock
      # operation of a certain service. The lock file should be removed.
      $machine->mustSucceed("dysnomia --type wrapper --operation unlock --component ${wrapper} --environment");
      $machine->mustSucceed("[ ! -f /tmp/wrapper.lock ]");

      # Deactivate the wrapper script.
      $machine->mustSucceed("dysnomia --type wrapper --operation deactivate --component ${wrapper} --environment");
      $machine->mustSucceed("sleep 5; [ ! -f /tmp/wrapper.state ]");

      # Deactivate again. This operation should succeed as it is idempotent.
      #$machine->mustSucceed("dysnomia --type wrapper --operation deactivate --component ${wrapper} --environment");
      #$machine->mustSucceed("sleep 5; [ ! -f /tmp/wrapper.state ]");
    '';
}
