{ enableApacheWebApplication ? false
, enableAxis2WebService ? false
, enableEjabberdDump ? false
, enableMySQLDatabase ? false
, enablePostgreSQLDatabase ? false
, enableTomcatWebApplication ? false
, enableMongoDatabase ? false
, enableSubversionRepository ? false
, enableInfluxDatabase ? false
, enableSupervisordProgram ? false
, enableSystemdUnit ? false
, enableDockerContainer ? false
, enableS6RCService ? false
, catalinaBaseDir ? "/var/tomcat"
, jobTemplate ? "systemd"
, enableLegacy ? false
, pkgs
, tarball
}:

pkgs.releaseTools.nixBuild {
  name = "dysnomia";
  version = builtins.readFile ./version;
  src = tarball;

  configureFlags = [
    (if enableApacheWebApplication then "--with-apache" else "--without-apache")
    (if enableAxis2WebService then "--with-axis2" else "--without-axis2")
    (if enableEjabberdDump then "--with-ejabberd" else "--without-ejabberd")
    (if enableMySQLDatabase then "--with-mysql" else "--without-mysql")
    (if enablePostgreSQLDatabase then "--with-postgresql" else "--without-postgresql")
    (if enableMongoDatabase then "--with-mongodb" else "--without-mongodb")
    (if enableTomcatWebApplication then "--with-tomcat=${catalinaBaseDir}" else "--without-tomcat")
    (if enableSubversionRepository then "--with-subversion" else "--without-subversion")
    (if enableInfluxDatabase then "--with-influxdb" else "--without-influxdb")
    (if enableSupervisordProgram then "--with-supervisord" else "--without-supervisord")
    (if enableSystemdUnit then "--with-systemd" else "--without-systemd")
    (if pkgs.stdenv.isDarwin then "--with-launchd" else "--without-launchd")
    (if enableDockerContainer then "--with-docker" else "--without-docker")
    (if enableS6RCService then "--with-s6-rc" else "--without-s6-rc")
    "--with-job-template=${jobTemplate}"
  ] ++ pkgs.lib.optional enableLegacy "--enable-legacy";

  buildInputs = [ pkgs.getopt pkgs.netcat ]
    ++ pkgs.stdenv.lib.optional enableEjabberdDump pkgs.ejabberd
    ++ pkgs.stdenv.lib.optional enableMySQLDatabase pkgs.mysql
    ++ pkgs.stdenv.lib.optional enablePostgreSQLDatabase pkgs.postgresql
    ++ pkgs.stdenv.lib.optional enableMongoDatabase pkgs.mongodb
    ++ pkgs.stdenv.lib.optional enableMongoDatabase pkgs.mongodb-tools
    ++ pkgs.stdenv.lib.optional enableSubversionRepository pkgs.subversion
    ++ pkgs.stdenv.lib.optional enableInfluxDatabase pkgs.influxdb
    ++ pkgs.stdenv.lib.optional enableSystemdUnit pkgs.systemd
    ++ pkgs.stdenv.lib.optional enableSupervisordProgram pkgs.pythonPackages.supervisor
    ++ pkgs.stdenv.lib.optional enableDockerContainer pkgs.docker
    ++ pkgs.stdenv.lib.optional enableS6RCService pkgs.s6-rc;
}
