{ buildFun,
  makeTest,
  pkgs,
  stdenv,
  tarball
}:

let
  dysnomia = buildFun {
    inherit pkgs tarball;
  };

  dummyUserComponent = import ./users/dummy-user-component.nix {
    inherit stdenv;
  };

  dummyHomeDirComponent = import ./users/dummy-homedir-component.nix {
    inherit stdenv;
  };
in
makeTest {
  name = "users";

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


    # Test creation and removal of a user with a dedicated group

    machine.succeed(
        "dysnomia-addgroups ${dummyUserComponent}"
    )
    machine.succeed(
        "dysnomia-addusers ${dummyUserComponent}"
    )
    check_modify_file_permissions()
    machine.succeed("[ -d /home/unprivileged ]")

    machine.succeed(
        "dysnomia-addgroups ${dummyUserComponent}"
    )
    machine.succeed(
        "dysnomia-addusers ${dummyUserComponent}"
    )
    check_modify_file_permissions()

    machine.succeed(
        "dysnomia-delusers ${dummyUserComponent}"
    )
    machine.succeed(
        "dysnomia-delgroups ${dummyUserComponent}"
    )
    check_fail_modify_file_permissions()

    # Test creation and removal of a user home directory, without actually creating users or groups

    machine.succeed("rm -rf /home/unprivileged")

    machine.succeed(
        "dysnomia-addgroups ${dummyHomeDirComponent}"
    )
    machine.succeed(
        "dysnomia-addusers ${dummyHomeDirComponent}"
    )
    machine.succeed("[ -d /home/unprivileged ]")

    machine.succeed(
        "dysnomia-addgroups ${dummyUserComponent}"
    )
    machine.succeed(
        "dysnomia-addusers ${dummyUserComponent}"
    )
    machine.succeed("[ -d /home/unprivileged ]")

    machine.succeed(
        "dysnomia-delusers ${dummyUserComponent}"
    )
    machine.succeed(
        "dysnomia-delgroups ${dummyUserComponent}"
    )
  '';
}
