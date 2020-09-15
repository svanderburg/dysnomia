{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    jobTemplate = "direct";
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
      start_all()

      # Test echo module. Here we just invoke the activate
      # and deactivation steps. This test should succeed.
      machine.succeed(
          "dysnomia --type echo --operation activate --component ${wrapper} --environment"
      )
      machine.succeed(
          "dysnomia --type echo --operation deactivate --component ${wrapper} --environment"
      )

      # Test shell feature. We execute a command that creates a temp file and we
      # check whether it exists.
      machine.succeed(
          "foo=foo dysnomia --type echo --shell --component ${wrapper} --environment --command 'echo \$foo > /tmp/tmpfile'"
      )
      machine.succeed("grep 'foo' /tmp/tmpfile")
    '';
}
