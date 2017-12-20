{config, lib, enableAuthentication}:

{
  process = {};
  wrapper = {};
}
// lib.optionalAttrs (config.services.httpd.enable) { apache-webapplication = {
  documentRoot = config.services.httpd.documentRoot;
}; }
// lib.optionalAttrs (config.services.tomcat.axis2.enable) { axis2-webservice = {}; }
// lib.optionalAttrs (config.services.ejabberd.enable) { ejabberd-dump = {
  ejabberdUser = config.services.ejabberd.user;
}; }
// lib.optionalAttrs (config.services.mysql.enable) { mysql-database = {
    mysqlPort = config.services.mysql.port;
  } // lib.optionalAttrs enableAuthentication {
    mysqlUsername = "root";
    mysqlPassword = builtins.readFile (config.services.mysql.rootPassword);
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
// lib.optionalAttrs (config.services.svnserve.enable) { subversion-repository = {
  svnBaseDir = config.services.svnserve.svnBaseDir;
}; }
