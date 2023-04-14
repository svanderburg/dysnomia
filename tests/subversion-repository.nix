{ buildFun,
  makeTest,
  pkgs,
  subversion,
  stdenv,
  tarball
}:

let
  dysnomia = buildFun {
    inherit pkgs tarball;
    enableSubversionRepository = true;
  };

  # Test services

  subversion_repository = import ./deployment/subversion-repository.nix {
    inherit stdenv;
  };

in
makeTest {
  name = "subversion-repository";

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
      def check_num_of_snapshot_generations(num):
          actual_num = machine.succeed(
              "ls /var/state/dysnomia/snapshots/subversion-repository/* | wc -l"
          )

          if int(num) != int(actual_num):
              raise Exception(
                  "Expecting {num} snapshot generations, but we have: {actual_num}".format(
                      num=num, actual_num=actual_num
                  )
              )


      start_all()

      subversionSettings = "svnBaseDir=/repos svnGroup=users"

      # Test Subversion module. We import a repository
      # then we do a checkout and see whether it succeeds.
      # This test should succeed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment"
      )
      machine.succeed(
          "${subversion}/bin/svn co file:///repos/testrepos"
      )
      machine.succeed("[ -e testrepos/index.php ]")

      # Activate the subversion repository again. It should not fail because of a double activation.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment"
      )

      # Take a snapshot of the Subversion repository.
      # This test should succeed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Take another snapshot of the Subversion repository. Because nothing
      # changed, no new snapshot is supposed to be taken. This test should
      # succeed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      machine.succeed(
          "cd testrepos; echo '<p>hello</p>' > hello.php; ${subversion}/bin/svn add hello.php; ${subversion}/bin/svn commit -m 'test commit'"
      )
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment"
      )
      check_num_of_snapshot_generations(2)

      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation collect-garbage --component ${subversion_repository} --environment"
      )
      machine.succeed(
          "cd testrepos; ${subversion}/bin/svn update"
      )

      # Deactivate the Subversion repository. This test should succeed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation deactivate --component ${subversion_repository} --environment"
      )

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation deactivate --component ${subversion_repository} --environment"
      )

      # Run the garbage collect operation. Since the repository has been
      # deactivated it is considered garbage, so it should be removed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation collect-garbage --component ${subversion_repository} --environment"
      )
      machine.fail(
          "cd testrepos; ${subversion}/bin/svn update"
      )

      # Activate the subversion repository again. This test should succeed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment"
      )

      # Restore the last snapshot and check whether it contains the recently
      # added file. This test should succeed.
      machine.succeed(
          subversionSettings
          + " dysnomia --type subversion-repository --operation restore --component ${subversion_repository} --environment"
      )
      machine.succeed("[ -e testrepos/hello.php ]")
    '';
}
