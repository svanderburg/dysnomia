{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableApacheWebApplication = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  # Test services
  
  apache_webapplication = import ./deployment/apache-webapplication.nix {
    inherit stdenv;
  };
in
makeTest {
  nodes = {
    machine = {config, pkgs, ...}:
      
    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;
        
      services.httpd = {
        enable = true;
        adminAddr = "foo@bar.com";
        documentRoot = "/var/www";
      };
        
      environment.systemPackages = [ dysnomia ];
    };
  };
  
  testScript =
    ''
      startAll;
      
      # Test Apache web application script. Here, we activate a small
      # static HTML website in the document root of Apache, then we
      # check whether it is available. Finally, we deactivate it again
      # and see whether is has become unavailable.
      # This test should succeed.
        
      $machine->waitForJob("httpd");
      $machine->mustSucceed("documentRoot=/var/www dysnomia --type apache-webapplication --operation activate --component ${apache_webapplication} --environment");
      $machine->mustSucceed("curl --fail http://localhost/test");
      
      # Activate again. This should succeed as the operation is idempotent
      $machine->mustSucceed("documentRoot=/var/www dysnomia --type apache-webapplication --operation activate --component ${apache_webapplication} --environment");
      $machine->mustSucceed("curl --fail http://localhost/test");
      
      # Deactivate the web application
      $machine->mustSucceed("documentRoot=/var/www dysnomia --type apache-webapplication --operation deactivate --component ${apache_webapplication} --environment");
      $machine->mustFail("curl --fail http://localhost/test");
      
      # Deactivate again. This should succeed as the operation is idempotent
      $machine->mustSucceed("documentRoot=/var/www dysnomia --type apache-webapplication --operation deactivate --component ${apache_webapplication} --environment");
      $machine->mustFail("curl --fail http://localhost/test");
    '';
}
