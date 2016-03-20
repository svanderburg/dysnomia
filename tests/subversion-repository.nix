{ nixpkgs, buildFun }:

let
  dysnomia = buildFun {
    system = builtins.currentSystem;
    enableSubversionRepository = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  # Test services
  
  subversion_repository = import ./deployment/subversion-repository.nix {
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
      
      # Test Subversion activation script. We import a repository
      # then we do a checkout and see whether it succeeds.
      # This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment");
      $machine->mustSucceed("${subversion}/bin/svn co file:///repos/testrepos");
      $machine->mustSucceed("[ -e testrepos/index.php ]");
      
      # Activate the subversion repository again. It should not fail because of a double activation.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment");
      
      # Take a snapshot of the Subversion repository.
      # This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/subversion-repository/* | wc -l)\" = \"1\" ]");
      
      # Take another snapshot of the Subversion repository. Because nothing
      # changed, no new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/subversion-repository/* | wc -l)\" = \"1\" ]");
      
      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      $machine->mustSucceed("cd testrepos; echo '<p>hello</p>' > hello.php; ${subversion}/bin/svn add hello.php; ${subversion}/bin/svn commit -m 'test commit'");
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation snapshot --component ${subversion_repository} --environment");
      $machine->mustSucceed("[ \"\$(ls /var/state/dysnomia/snapshots/subversion-repository/* | wc -l)\" = \"2\" ]");
      
      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation collect-garbage --component ${subversion_repository} --environment");
      $machine->mustSucceed("cd testrepos; ${subversion}/bin/svn update");
      
      # Deactivate the Subversion repository. This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation deactivate --component ${subversion_repository} --environment");
    
      # Run the garbage collect operation. Since the repository has been
      # deactivated it is considered garbage, so it should be removed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation collect-garbage --component ${subversion_repository} --environment");
      $machine->mustFail("cd testrepos; ${subversion}/bin/svn update");
      
      # Activate the subversion repository again. This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation activate --component ${subversion_repository} --environment");
      
      # Restore the last snapshot and check whether it contains the recently
      # added file. This test should succeed.
      $machine->mustSucceed("svnBaseDir=/repos svnGroup=users dysnomia --type subversion-repository --operation restore --component ${subversion_repository} --environment");
      my $result = $machine->mustSucceed("[ -e testrepos/hello.php ]");
    '';
}
