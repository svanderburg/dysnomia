{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  fileset = import ./deployment/fileset.nix {
    inherit stdenv;
  };
in
makeTest {
  name = "fileset";

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
      def check_files_deployed():
          machine.succeed("/srv/fileset/bin/showfiles")


      def check_files_undeployed():
          machine.fail("/srv/fileset/bin/showfiles")


      start_all()

      # Test the activation step. It should expose the script in the bin/ folder
      machine.succeed(
          "dysnomia --type fileset --operation activate --component ${fileset} --environment"
      )
      check_files_deployed()

      # Activate again. This should work, since the activation step should be idempotent
      machine.succeed(
          "dysnomia --type fileset --operation activate --component ${fileset} --environment"
      )
      check_files_deployed()

      # Deactivate. The executable should have been removed.
      machine.succeed(
          "dysnomia --type fileset --operation deactivate --component ${fileset} --environment"
      )
      check_files_undeployed()

      # Activate again.
      machine.succeed(
          "dysnomia --type fileset --operation activate --component ${fileset} --environment"
      )

      # Create some random files and create a snapshot. We should receive a tarball that contains the files.
      machine.succeed("echo hello > /srv/fileset/files/hello")
      machine.succeed("echo bye > /srv/fileset/files/bye")
      machine.succeed(
          "dysnomia --type fileset --operation snapshot --component ${fileset} --environment"
      )

      result = machine.succeed("dysnomia-snapshots --query-all | wc -l")

      if int(result) == 1:
          print("We have 1 snapshot!")
      else:
          raise Exception("We should have 1 snapshot, instead we have: {}".format(result))

      snapshot = machine.succeed(
          "dysnomia-snapshots --resolve $(dysnomia-snapshots --query-latest)"
      )

      result = machine.succeed("tar tf {}/state.tar.xz | wc -l".format(snapshot[:-1]))

      if int(result) == 3:
          print("We have 3 tar entries!")
      else:
          raise Exception("We should have 3 tar, instead we have: {}".format(result))

      # Take another snapshot. Because nothing has changed, we should still have only one snapshot.
      machine.succeed(
          "dysnomia --type fileset --operation snapshot --component ${fileset} --environment"
      )

      result = machine.succeed("dysnomia-snapshots --query-all | wc -l")

      if int(result) == 1:
          print("We have 1 snapshot!")
      else:
          raise Exception("We should have 1 snapshot, instead we have: {}".format(result))

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken.

      machine.succeed("echo world > /srv/fileset/files/world")
      machine.succeed(
          "dysnomia --type fileset --operation snapshot --component ${fileset} --environment"
      )

      result = machine.succeed("dysnomia-snapshots --query-all | wc -l")

      if int(result) == 2:
          print("We have 2 snapshots!")
      else:
          raise Exception("We should have 2 snapshots, instead we have: {}".format(result))

      snapshot = machine.succeed(
          "dysnomia-snapshots --resolve $(dysnomia-snapshots --query-latest)"
      )

      result = machine.succeed("tar tf {}/state.tar.xz | wc -l".format(snapshot[:-1]))

      if int(result) == 4:
          print("We have 4 tar entries!")
      else:
          raise Exception("We should have 4 tar entries, instead we have: {}".format(result))

      # Run the garbage collect operation. Since the state is not considered
      # garbage yet, it should not be removed.
      machine.succeed(
          "dysnomia --type fileset --operation collect-garbage --component ${fileset} --environment"
      )

      result = machine.succeed("ls /srv/fileset/files | wc -l")

      if int(result) == 3:
          print("We have 3 files!")
      else:
          raise Exception("We should have 3 files, instead we have: {}".format(result))

      # Deactivate. The executable should have been removed.
      machine.succeed(
          "dysnomia --type fileset --operation deactivate --component ${fileset} --environment"
      )
      machine.fail("/srv/fileset/bin/showfiles")

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          "dysnomia --type fileset --operation deactivate --component ${fileset} --environment"
      )

      # Run the garbage collect operation. Since the state has been
      # deactivated it is considered garbage, so it should be removed.

      machine.succeed(
          "dysnomia --type fileset --operation collect-garbage --component ${fileset} --environment"
      )

      result = machine.succeed("[ ! -e /srv/fileset/files ]")

      # Activate again.
      machine.succeed(
          "dysnomia --type fileset --operation activate --component ${fileset} --environment"
      )

      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.

      machine.succeed(
          "dysnomia --type fileset --operation restore --component ${fileset} --environment"
      )
      machine.succeed("[ -f /srv/fileset/files/world ]")
    '';
}
