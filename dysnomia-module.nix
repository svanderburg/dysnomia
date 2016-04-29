{pkgs, lib, config, ...}:

with lib;

let
  cfg = config.dysnomia;
  
  containersDir = pkgs.stdenv.mkDerivation {
    name = "dysnomia-containers";
    buildCommand = ''
      mkdir -p $out
      cd $out
      
      ${concatMapStrings (containerName:
        let
          containerProperties = cfg.containers."${containerName}";
        in
        ''
          cat > ${containerName} <<EOF
          ${concatMapStrings (propertyName: "${propertyName}=${toString containerProperties."${propertyName}"}\n") (builtins.attrNames containerProperties)}
          type=${containerName}
          EOF
        ''
      ) (builtins.attrNames cfg.containers)}
    '';
  };
  
  linkMutableComponents = {containerName}:
    ''
      mkdir ${containerName}
      
      ${concatMapStrings (componentName:
        let
          component = cfg.components."${containerName}"."${componentName}";
        in
        "ln -s ${component} ${containerName}/${componentName}\n"
      ) (builtins.attrNames (cfg.components."${containerName}" or {}))}
    '';
  
  componentsDir = pkgs.stdenv.mkDerivation {
    name = "dysnomia-components";
    buildCommand = ''
      mkdir -p $out
      cd $out
      
      ${concatMapStrings (containerName:
        let
          components = cfg.components."${containerName}";
        in
        linkMutableComponents { inherit containerName; }
      ) (builtins.attrNames cfg.components)}
    '';
  };
in
{
  options = {
    dysnomia = {
      
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Dysnomia";
      };
      
      package = mkOption {
        type = types.path;
        description = "The Dysnomia package";
      };
      
      containers = mkOption {
        description = "An attribute set in which each key represents a container and each value an attribute set providing its configuration properties";
        default = {};
      };
      
      components = mkOption {
        description = "An atttribute set in which each key represents a container and each value an attribute set in which each key represents a component and each value a derivation constructing its initial state";
        default = {};
      };
    };
  };
  
  config = mkIf cfg.enable {
  
    environment.etc = {
      "dysnomia/containers" = {
        source = containersDir;
      };
      "dysnomia/components" = {
        source = componentsDir;
      };
    };
    
    environment.variables = {
      DYSNOMIA_STATEDIR = "/var/state/dysnomia-nixos";
    };
    
    environment.systemPackages = [ cfg.package ];
    
    dysnomia.package = mkDefault (import ./build.nix {
      enableApacheWebApplication = config.services.httpd.enable;
      enableAxis2WebService = config.services.tomcat.axis2.enable;
      enableEjabberdDump = config.services.ejabberd.enable;
      enableMySQLDatabase = config.services.mysql.enable;
      enablePostgreSQLDatabase = config.services.postgresql.enable;
      enableTomcatWebApplication = config.services.tomcat.enable;
      enableMongoDatabase = config.services.mongodb.enable;
      enableSubversionRepository = config.services.svnserve.enable;
      jobTemplate = "systemd";
      inherit pkgs;
      tarball = (import ./release.nix {}).tarball;
    });
    
    dysnomia.containers = import ./nix/generate-containers.nix {
      inherit config lib;
      enableAuthentication = true;
    };
    
    system.activationScripts.dysnomia = ''
      mkdir -p /etc/systemd-mutable/system
      if [ ! -f /etc/systemd-mutable/system/dysnomia.target ]
      then
          ( echo "[Unit]"
            echo "Description=Services that are activated and deactivated by Dysnomia"
            echo "After=final.target"
          ) > /etc/systemd-mutable/system/dysnomia.target
      fi
    '';
  };
}
