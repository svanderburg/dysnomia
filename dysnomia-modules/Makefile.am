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

# Build settings

libexec_SCRIPTS = echo process nixos-configuration wrapper $(apache_webapplication) $(axis2_webservice) $(ejabberd_dump) $(iis_webapplication) $(mysql_database) $(mssql_database) $(tomcat_webapplication) $(postgresql_database) $(subversion_repository)

EXTRA_DIST = apache-webapplication axis2-webservice.in echo ejabberd-dump.in iis-webapplication.in mssql-database.in mysql-database.in process nixos-configuration tomcat-webapplication.in wrapper postgresql-database.in subversion-repository.in
