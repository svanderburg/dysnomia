{ enableApacheWebApplication ? false
, enableAxis2WebService ? false
, enableEjabberdDump ? false
, enableMySQLDatabase ? false
, enablePostgreSQLDatabase ? false
, enableTomcatWebApplication ? false
, enableMongoDatabase ? false
, enableSubversionRepository ? false
, catalinaBaseDir ? "/var/tomcat"
, jobTemplate ? "systemd"
, pkgs
, tarball
}:

pkgs.releaseTools.nixBuild {
  name = "dysnomia";
  version = builtins.readFile ./version;
  src = tarball;
  
  preConfigure = pkgs.stdenv.lib.optionalString enableEjabberdDump "export PATH=$PATH:${pkgs.ejabberd}/sbin";

  configureFlags = [
    (if enableApacheWebApplication then "--with-apache" else "--without-apache")
    (if enableAxis2WebService then "--with-axis2" else "--without-axis2")
    (if enableEjabberdDump then "--with-ejabberd" else "--without-ejabberd")
    (if enableMySQLDatabase then "--with-mysql" else "--without-mysql")
    (if enablePostgreSQLDatabase then "--with-postgresql" else "--without-postgresql")
    (if enableMongoDatabase then "--with-mongodb" else "--without-mongodb")
    (if enableTomcatWebApplication then "--with-tomcat=${catalinaBaseDir}" else "--without-tomcat")
    (if enableSubversionRepository then "--with-subversion" else "--without-subversion")
    "--with-job-template=${jobTemplate}"
  ];
    
  buildInputs = [ pkgs.getopt ]
    ++ pkgs.stdenv.lib.optional enableEjabberdDump pkgs.ejabberd
    ++ pkgs.stdenv.lib.optional enableMySQLDatabase pkgs.mysql
    ++ pkgs.stdenv.lib.optional enablePostgreSQLDatabase pkgs.postgresql
    ++ pkgs.stdenv.lib.optional enableMongoDatabase pkgs.mongodb
    ++ pkgs.stdenv.lib.optional enableMongoDatabase pkgs.mongodb-tools
    ++ pkgs.stdenv.lib.optional enableSubversionRepository pkgs.subversion;
}
