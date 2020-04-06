# Optional scripts

if have_apache
    apache_webapplication = apache-webapplication
endif

if have_axis2
    axis2_webservice = axis2-webservice
endif

if have_ejabberd
    ejabberd_dump = ejabberd-dump
endif

if have_iis
    iis_webapplication = iis-webapplication
endif

if have_mssql
    mssql_database = mssql-database
endif

if have_mysql
    mysql_database = mysql-database
endif

if have_postgresql
    postgresql_database = postgresql-database
endif

if have_tomcat
    tomcat_webapplication = tomcat-webapplication
endif

if have_subversion
    subversion_repository = subversion-repository
endif

if have_mongodb
    mongo_database = mongo-database
endif

if have_influxdb
    influx_database = influx-database
endif

if have_systemd
    systemd_unit = systemd-unit
endif

if have_supervisord
    supervisord_program = supervisord-program
endif

if have_launchd
    launchd_daemon = launchd-daemon
endif

if have_cygrunsrv
    cygrunsrv_service = cygrunsrv-service
endif

# Build settings

libexec_SCRIPTS = echo fileset process nixos-configuration wrapper sysvinit-script bsdrc-script managed-process $(apache_webapplication) $(axis2_webservice) $(ejabberd_dump) $(iis_webapplication) $(mysql_database) $(mssql_database) $(tomcat_webapplication) $(postgresql_database) $(subversion_repository) $(mongo_database) $(influx_database) $(systemd_unit) $(supervisord_program) $(launchd_daemon) $(cygrunsrv_service)
pkgdata_SCRIPTS = util

EXTRA_DIST = apache-webapplication.in axis2-webservice.in echo ejabberd-dump.in fileset.in iis-webapplication.in mssql-database.in mysql-database.in process.in nixos-configuration.in tomcat-webapplication.in wrapper.in postgresql-database.in subversion-repository.in mongo-database.in influx-database.in sysvinit-script.in bsdrc-script.in systemd-unit.in supervisord-program.in launchd-daemon.in cygrunsrv-service.in managed-process.in util
