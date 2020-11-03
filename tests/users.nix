{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableMySQLDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  dummyComponent = import ./users/dummy-component.nix {
    inherit stdenv;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:

    {
      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript = ''
    def check_modify_file_permissions():
        machine.succeed("touch dummyfile")
        machine.succeed("chown unprivileged:unprivileged dummyfile")
        machine.succeed("rm dummyfile")


    def check_fail_modify_file_permissions():
        machine.succeed("touch dummyfile")
        machine.fail("chown unprivileged:unprivileged dummyfile")
        machine.succeed("rm dummyfile")


    machine.succeed(
        "dysnomia-addgroups ${dummyComponent}"
    )
    machine.succeed(
        "dysnomia-addusers ${dummyComponent}"
    )
    check_modify_file_permissions()

    machine.succeed(
        "dysnomia-addgroups ${dummyComponent}"
    )
    machine.succeed(
        "dysnomia-addusers ${dummyComponent}"
    )
    check_modify_file_permissions()

    machine.succeed(
        "dysnomia-delusers ${dummyComponent}"
    )
    machine.succeed(
        "dysnomia-delgroups ${dummyComponent}"
    )
    check_fail_modify_file_permissions()
  '';
}
