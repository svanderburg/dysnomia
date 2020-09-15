{config, lib, enableAuthentication}:

{
  process = {};
  wrapper = {};
}
// lib.optionalAttrs (config.services.httpd.enable) { apache-webapplication = {
  documentRoot = config.services.httpd.virtualHosts.localhost.documentRoot;
}; }
// lib.optionalAttrs (config.services.tomcat.axis2.enable) { axis2-webservice = {}; }
// lib.optionalAttrs (config.services.ejabberd.enable) { ejabberd-dump = {
  ejabberdUser = config.services.ejabberd.user;
}; }
// lib.optionalAttrs (config.services.mysql.enable) { mysql-database = {
    mysqlPort = config.services.mysql.port;
    mysqlSocket = "/run/mysqld/mysqld.sock";
  };
}
// lib.optionalAttrs (config.services.postgresql.enable) { postgresql-database = {
  } // lib.optionalAttrs enableAuthentication {
    postgresqlUsername = "postgres";
  };
}
// lib.optionalAttrs (config.services.tomcat.enable) { tomcat-webapplication = {
  tomcatPort = 8080;
}; }
// lib.optionalAttrs (config.services.mongodb.enable) { mongo-database = {}; }
// lib.optionalAttrs (config.services.influxdb.enable) {
  influx-database = {
    influxdbUsername = config.services.influxdb.user;
    influxdbDataDir = "${config.services.influxdb.dataDir}/data";
    influxdbMetaDir = "${config.services.influxdb.dataDir}/meta";
  };
}
// lib.optionalAttrs (config.services.svnserve.enable) { subversion-repository = {
  svnBaseDir = config.services.svnserve.svnBaseDir;
}; }
