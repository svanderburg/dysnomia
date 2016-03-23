{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableAxis2WebService = true;
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
  
  axis2_webservice = import ./deployment/axis2-webservice.nix {
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
      services.tomcat.axis2.enable = true;
        
      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      startAll;
      
      $machine->waitForJob("tomcat");

      # Test Axis2 web service script.
      
      $machine->waitForFile("/var/tomcat/webapps/axis2");
      $machine->mustSucceed("dysnomia --type axis2-webservice --operation activate --component ${axis2_webservice} --environment");
      $machine->mustSucceed("sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"); # !!! We must wait a while to let it become active
      $machine->mustSucceed("dysnomia --type axis2-webservice --operation deactivate --component ${axis2_webservice} --environment");
      $machine->mustFail("sleep 10; curl --fail http://localhost:8080/axis2/services/Test/test"); # !!! We must wait a while to let it become inactive
    '';
}
