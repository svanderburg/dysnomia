{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  # Test services

  fileset = import ./deployment/fileset.nix {
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

      # Test the activation step. It should expose the script in the bin/ folder
      $machine->mustSucceed("dysnomia --type fileset --operation activate --component ${fileset} --environment");
      $machine->mustSucceed("/srv/fileset/bin/showfiles");

      # Activate again. This should work, since the activation step should be idempotent
      $machine->mustSucceed("dysnomia --type fileset --operation activate --component ${fileset} --environment");
      $machine->mustSucceed("/srv/fileset/bin/showfiles");

      # Deactivate. The executable should have been removed.
      $machine->mustSucceed("dysnomia --type fileset --operation deactivate --component ${fileset} --environment");
      $machine->mustFail("/srv/fileset/bin/showfiles");

      # Activate again.
      $machine->mustSucceed("dysnomia --type fileset --operation activate --component ${fileset} --environment");

      # Create some random files and create a snapshot. We should receive a tarball that contains the files.
      $machine->mustSucceed("echo hello > /srv/fileset/files/hello");
      $machine->mustSucceed("echo bye > /srv/fileset/files/bye");
      $machine->mustSucceed("dysnomia --type fileset --operation snapshot --component ${fileset} --environment");

      my $result = $machine->mustSucceed("dysnomia-snapshots --query-all | wc -l");

      if($result == 1) {
          print "We have 1 snapshot!\n";
      } else {
          die "We should have 1, instead we have: $result";
      }

      my $snapshot = $machine->mustSucceed("dysnomia-snapshots --resolve \$(dysnomia-snapshots --query-latest)");

      $result = $machine->mustSucceed("tar tf ".(substr $snapshot, 0, -1)."/state.tar.xz | wc -l");

      if($result == 3) {
          print "We have 3 tar entries!\n";
      } else {
          die "We should have 3 tar, instead we have: $result";
      }

      # Take another snapshot. Because nothing has changed, we should still have only one snapshot.
      $machine->mustSucceed("dysnomia --type fileset --operation snapshot --component ${fileset} --environment");

      $result = $machine->mustSucceed("dysnomia-snapshots --query-all | wc -l");

      if($result == 1) {
          print "We have 1 snapshot!\n";
      } else {
          die "We should have 1 snapshot, instead we have: $result";
      }

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken.

      $machine->mustSucceed("echo world > /srv/fileset/files/world");
      $machine->mustSucceed("dysnomia --type fileset --operation snapshot --component ${fileset} --environment");

      $result = $machine->mustSucceed("dysnomia-snapshots --query-all | wc -l");

      if($result == 2) {
          print "We have 2 snapshots!\n";
      } else {
          die "We should have 2 snapshots, instead we have: $result";
      }

      $snapshot = $machine->mustSucceed("dysnomia-snapshots --resolve \$(dysnomia-snapshots --query-latest)");

      $result = $machine->mustSucceed("tar tf ".(substr $snapshot, 0, -1)."/state.tar.xz | wc -l");

      if($result == 4) {
          print "We have 4 tar entries!\n";
      } else {
          die "We should have 4 tar entries, instead we have: $result";
      }

      # Run the garbage collect operation. Since the state is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("dysnomia --type fileset --operation collect-garbage --component ${fileset} --environment");

      $result = $machine->mustSucceed("ls /srv/fileset/files | wc -l");

      if($result == 3) {
          print "We have 3 files!\n";
      } else {
          die "We should have 3 files, instead we have: $result";
      }

      # Deactivate. The executable should have been removed.
      $machine->mustSucceed("dysnomia --type fileset --operation deactivate --component ${fileset} --environment");
      $machine->mustFail("/srv/fileset/bin/showfiles");

      # Deactivate again. This test should succeed as the operation is idempotent.
      $machine->mustSucceed("dysnomia --type fileset --operation deactivate --component ${fileset} --environment");

      # Run the garbage collect operation. Since the state has been
      # deactivated it is considered garbage, so it should be removed.

      $machine->mustSucceed("dysnomia --type fileset --operation collect-garbage --component ${fileset} --environment");

      $result = $machine->mustSucceed("ls /srv/fileset/files | wc -l");

      if($result == 0) {
          print "We have 0 files!\n";
      } else {
          die "We should have 0 files, instead we have: $result";
      }

      # Activate again.
      $machine->mustSucceed("dysnomia --type fileset --operation activate --component ${fileset} --environment");

      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.

      $machine->mustSucceed("dysnomia --type fileset --operation restore --component ${fileset} --environment");
      $result = $machine->mustSucceed("[ -f /srv/fileset/files/world ]");
    '';
}
