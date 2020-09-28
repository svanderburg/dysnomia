{pkgs, lib, config, ...}:

with lib;

let
  cfg = config.dysnomiaTest;

  printProperties = properties:
    concatMapStrings (propertyName:
      let
        property = properties."${propertyName}";
      in
      if isList property then "${propertyName}=(${lib.concatMapStrings (elem: "\"${toString elem}\" ") (properties."${propertyName}")})\n"
      else "${propertyName}=\"${toString property}\"\n"
    ) (builtins.attrNames properties);

  properties = pkgs.stdenv.mkDerivation {
    name = "dysnomia-properties";
    buildCommand = ''
      cat > $out << "EOF"
      ${printProperties cfg.properties}
      EOF
    '';
  };

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
          ${printProperties containerProperties}
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

  dysnomiaFlags = {
    enableApacheWebApplication = config.services.httpd.enable;
    enableAxis2WebService = config.services.tomcat.axis2.enable;
    enableDockerContainer = config.virtualisation.docker.enable;
    enableEjabberdDump = config.services.ejabberd.enable;
    enableMySQLDatabase = config.services.mysql.enable;
    enablePostgreSQLDatabase = config.services.postgresql.enable;
    enableTomcatWebApplication = config.services.tomcat.enable;
    enableMongoDatabase = config.services.mongodb.enable;
    enableSubversionRepository = config.services.svnserve.enable;
    enableInfluxDatabase = config.services.influxdb.enable;
  };
in
{
  options = {
    dysnomiaTest = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Dysnomia";
      };

      enableAuthentication = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to publish privacy-sensitive authentication credentials";
      };

      package = mkOption {
        type = types.path;
        description = "The Dysnomia package";
      };

      properties = mkOption {
        description = "An attribute set in which each attribute represents a machine property. Optionally, these values can be shell substitutions.";
        default = {};
      };

      containers = mkOption {
        description = "An attribute set in which each key represents a container and each value an attribute set providing its configuration properties";
        default = {};
      };

      components = mkOption {
        description = "An atttribute set in which each key represents a container and each value an attribute set in which each key represents a component and each value a derivation constructing its initial state";
        default = {};
      };

      extraContainerProperties = mkOption {
        description = "An attribute set providing additional container settings in addition to the default properties";
        default = {};
      };

      extraContainerPaths = mkOption {
        description = "A list of paths containing additional container configurations that are added to the search folders";
        default = [];
      };

      extraModulePaths = mkOption {
        description = "A list of paths containing additional modules that are added to the search folders";
        default = [];
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
      "dysnomia/properties" = {
        source = properties;
      };
    };

    environment.variables = {
      DYSNOMIA_STATEDIR = "/var/state/dysnomia-nixos";
      DYSNOMIA_CONTAINERS_PATH = "${lib.concatMapStrings (containerPath: "${containerPath}:") cfg.extraContainerPaths}/etc/dysnomia/containers";
      DYSNOMIA_MODULES_PATH = "${lib.concatMapStrings (modulePath: "${modulePath}:") cfg.extraModulePaths}/etc/dysnomia/modules";
    };

    environment.systemPackages = [ cfg.package ];

    dysnomiaTest.package = mkDefault (import ./build.nix ({
      jobTemplate = "systemd";
      inherit pkgs;
      tarball = (import ./release.nix {}).tarball;
    } // dysnomiaFlags));

    dysnomiaTest.properties = {
      hostname = config.networking.hostName;
      system = if config.nixpkgs ? localSystem && config.nixpkgs.localSystem.system != "" then config.nixpkgs.localSystem.system # Support compatiblity with Nixpkgs 17.09 and newer versions
        else if config.nixpkgs.system != "" then config.nixpkgs.system
        else builtins.currentSystem;

      supportedTypes = [
        "echo"
        "fileset"
        "process"
        "wrapper"

        # These are not base modules, but they are still enabled because they work with technology that are always enabled in NixOS
        "systemd-unit"
        "nixos-configuration"
      ]
      ++ optional (dysnomiaFlags.enableApacheWebApplication) "apache-webapplication"
      ++ optional (dysnomiaFlags.enableAxis2WebService) "axis2-webservice"
      ++ optional (dysnomiaFlags.enableDockerContainer) "docker-container"
      ++ optional (dysnomiaFlags.enableEjabberdDump) "ejabberd-dump"
      ++ optional (dysnomiaFlags.enableInfluxDatabase) "influx-database"
      ++ optional (dysnomiaFlags.enableMySQLDatabase) "mysql-database"
      ++ optional (dysnomiaFlags.enablePostgreSQLDatabase) "postgresql-database"
      ++ optional (dysnomiaFlags.enableTomcatWebApplication) "tomcat-webapplication"
      ++ optional (dysnomiaFlags.enableMongoDatabase) "mongo-database"
      ++ optional (dysnomiaFlags.enableSubversionRepository) "subversion-repository";
    };

    dysnomiaTest.containers = lib.recursiveUpdate (import ./nix/generate-containers.nix {
      inherit config lib;
      inherit (cfg) enableAuthentication;
    }) cfg.extraContainerProperties;

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
