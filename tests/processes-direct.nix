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
  # Test services
  
  wrapper = import ./deployment/wrapper.nix {
    inherit stdenv;
  };
  
  wrapper_unprivileged = import ./deployment/wrapper-unprivileged.nix {
    inherit stdenv;
  };
  
  process = import ./deployment/process.nix {
    inherit stdenv;
  };
  
  process_unprivileged = import ./deployment/process-unprivileged.nix {
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
      
      # Test wrapper activation script. Here we invoke the wrapper
      # of a certain service. On activation it writes a state file in
      # the temp folder.
      # This test should succeed.
        
      $machine->mustSucceed("dysnomia --type wrapper --operation activate --component ${wrapper} --environment");
      $machine->mustSucceed("sleep 5; [ \"\$(cat /tmp/wrapper.state)\" = \"wrapper active\" ]");
      $machine->mustSucceed("[ \"\$(stat -c %U /tmp/wrapper.state)\" = \"root\" ]");
      
      # Test wrapper activation script. Here we invoke the lock
      # operation of a certain service. It should write a lock file
      # into the temp dir and it should be owned by root.
      # This test should succeed.
      
      $machine->mustSucceed("dysnomia --type wrapper --operation lock --component ${wrapper} --environment");
      $machine->mustSucceed("[ \"\$(stat -c %U /tmp/wrapper.lock)\" = \"root\" ]");
      
      # Test wrapper activation script. Here we invoke the unlock
      # operation of a certain service. The lock file should be removed.
      # This test should succeed.
      
      $machine->mustSucceed("dysnomia --type wrapper --operation unlock --component ${wrapper} --environment");
      $machine->mustSucceed("[ ! -f /tmp/wrapper.lock ]");
      
      # Deactivate the wrapper script. We also check whether the file created
      # on activation is owned by root.
      # This test should succeed.
      
      $machine->mustSucceed("dysnomia --type wrapper --operation deactivate --component ${wrapper} --environment");
      $machine->mustSucceed("sleep 5; [ ! -f /tmp/wrapper.state ]");
      
      # Test wrapper activation script. Here we invoke the wrapper
      # of a certain service. On activation it writes a state file in
      # the temp folder. After a while we deactivate it and we check
      # if the state file is removed. We also check whether the file is owned
      # by an unprivileged user.
      # This test should succeed.
      
      $machine->mustSucceed("dysnomia --type wrapper --operation activate --component ${wrapper_unprivileged} --environment");
      $machine->mustSucceed("sleep 5; [ \"\$(cat /tmp/wrapper.state)\" = \"wrapper active\" ]");
      $machine->mustSucceed("[ \"\$(stat -c %U /tmp/wrapper.state)\" = \"unprivileged\" ]");
      
      # Test wrapper activation script. Here we invoke the lock
      # operation of a certain service. It should write a lock file
      # into the temp dir and it should be owned by an unprivileged user.
      # This test should succeed.
      
      $machine->mustSucceed("dysnomia --type wrapper --operation lock --component ${wrapper_unprivileged} --environment");
      $machine->mustSucceed("[ \"\$(stat -c %U /tmp/wrapper.lock)\" = \"unprivileged\" ]");
      
      # Test wrapper activation script. Here we invoke the unlock
      # operation of a certain service. The lock file should be removed.
      # This test should succeed.
      
      $machine->mustSucceed("dysnomia --type wrapper --operation unlock --component ${wrapper_unprivileged} --environment");
      $machine->mustSucceed("[ ! -f /tmp/wrapper.lock ]");
      
      # Deactivate the wrapper script. We also check whether the file created
      # on activation is owned by the unprivileged user.
      # This test should succeed.
      
      $machine->mustSucceed("dysnomia --type wrapper --operation deactivate --component ${wrapper_unprivileged} --environment");
      $machine->mustSucceed("sleep 5; [ ! -f /tmp/wrapper.state ]");
      
      # Test process activation script. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as root.
      # This test should succeed.
        
      $machine->mustSucceed("dysnomia --type process --operation activate --component ${process} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${process}/bin/loop | grep -v grep | grep root)\" != \"\" ]");
      
      $machine->mustSucceed("dysnomia --type process --operation deactivate --component ${process} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${process}/bin/loop | grep -v grep | grep root)\" = \"\" ]");
      
      # Test process activation script. Here we start a process which
      # loops forever. We check whether it has been started and
      # then we deactivate it again and verify whether it has been
      # stopped. We also check if the process runs as an uprivileged user.
      # This test should succeed.
        
      $machine->mustSucceed("dysnomia --type process --operation activate --component ${process_unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${process_unprivileged}/bin/loop | grep -v grep | grep unprivileged)\" != \"\" ]");
      
      $machine->mustSucceed("dysnomia --type process --operation deactivate --component ${process_unprivileged} --environment");
      $machine->mustSucceed("sleep 5");
      $machine->mustSucceed("[ \"\$(ps aux | grep ${process_unprivileged}/bin/loop | grep -v grep | grep unprivileged)\" = \"\" ]");
    '';
}
