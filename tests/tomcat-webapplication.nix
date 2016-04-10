{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableTomcatWebApplication = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  # Test services
  
  tomcat_webapplication = import ./deployment/tomcat-webapplication.nix {
    inherit stdenv jdk;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:
      
    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;
        
      services.tomcat.enable = true;
        
      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      startAll;
      
      # Test Tomcat web application script. Deploys a tomcat web
      # application, verifies whether it can be accessed and then
      # undeploys it again and checks whether it becomes inaccessible.
      # This test should succeed.
        
      $machine->waitForJob("tomcat");
      $machine->mustSucceed("dysnomia --type tomcat-webapplication --operation activate --component ${tomcat_webapplication} --environment");
      $machine->waitForFile("/var/tomcat/webapps/tomcat-webapplication");
      $machine->mustSucceed("curl --fail http://localhost:8080/tomcat-webapplication");
      
      # Activate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type tomcat-webapplication --operation activate --component ${tomcat_webapplication} --environment");
      $machine->waitForFile("/var/tomcat/webapps/tomcat-webapplication");
      $machine->mustSucceed("curl --fail http://localhost:8080/tomcat-webapplication");
      
      $machine->mustSucceed("dysnomia --type tomcat-webapplication --operation deactivate --component ${tomcat_webapplication} --environment");
      $machine->mustSucceed("while [ -e /var/tomcat/webapps/tomcat-webapplication ]; do echo 'Waiting to undeploy' >&2; sleep 1; done");
      $machine->mustFail("curl --fail http://localhost:8080/tomcat-webapplication");
      
      # Deactivate again. This operation should succeed as it is idempotent.
      $machine->mustSucceed("dysnomia --type tomcat-webapplication --operation deactivate --component ${tomcat_webapplication} --environment");
      $machine->mustSucceed("while [ -e /var/tomcat/webapps/tomcat-webapplication ]; do echo 'Waiting to undeploy' >&2; sleep 1; done");
      $machine->mustFail("curl --fail http://localhost:8080/tomcat-webapplication");
    '';
}
