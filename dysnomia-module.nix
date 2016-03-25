{pkgs, lib, config, ...}:

with lib;

let
  cfg = config.services.dysnomia;
  
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
          ${concatMapStrings (propertyName: "${propertyName}=${containerProperties."${propertyName}"}\n") (builtins.attrNames containerProperties)}
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
        "ln -s ${component} ${containerName}/${componentName}"
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
    services.dysnomia = {
      
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Dysnomia";
      };
      
      package = mkOption {
        type = types.path;
        #default = pkgs.dysnomia; # TODO: refer to package with required plugins enabled
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
  
    programs.bash.loginShellInit = ''
      export DYSNOMIA_CONTAINERS_PATH=${containersDir}
      export DYSNOMIA_COMPONENTS_PATH=${componentsDir}
      export DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos
    '';
    
    services.dysnomia.package = mkDefault (import ./build.nix {
      enableApacheWebApplication = config.services.httpd.enable;
      enableAxis2WebService = config.services.tomcat.axis2.enable;
      enableEjabberdDump = config.services.ejabberd.enable;
      enableMySQLDatabase = config.services.mysql.enable;
      enablePostgreSQLDatabase = config.services.postgresql.enable;
      enableTomcatWebApplication = config.services.tomcat.enable;
      enableMongoDatabase = config.services.mongodb.enable;
      enableSubversionRepository = true; # TODO: how to reliably detect this?
      jobTemplate = "systemd";
      inherit pkgs;
      tarball = (import ./release.nix {}).tarball;
    });
    
    services.dysnomia.containers = {
      process = {};
      wrapper = {};
    }
    // lib.optionalAttrs (config.services.httpd.enable) { apache-webapplication = {}; }
    // lib.optionalAttrs (config.services.tomcat.axis2.enable) { axis2-webservice = {}; }
    // lib.optionalAttrs (config.services.ejabberd.enable) { ejabberd-dump = {
      ejabberdUser = config.services.ejabberd.user;
    }; }
    // lib.optionalAttrs (config.services.mysql.enable) { mysql-database = {
      mysqlUsername = "root";
      mysqlPassword = builtins.readFile (config.services.mysql.rootPassword);
    }; }
    // lib.optionalAttrs (config.services.postgresql.enable) { postgresql-database = {
      postgresqlUsername = "root";
    }; }
    // lib.optionalAttrs (config.services.tomcat.enable) { tomcat-webapplication = {}; }
    // lib.optionalAttrs (config.services.mongodb.enable) { mongo-database = {}; };
    
    environment.systemPackages = [ cfg.package ];
  };
}
