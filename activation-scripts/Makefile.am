# Optional scripts

if have_ejabberd
    ejabberd_dump = ejabberd-dump
endif

if have_mysql
    mysql_database = mysql-database
endif

if have_tomcat
    tomcat_webapplication = tomcat-webapplication
endif


# Build settings

libexec_SCRIPTS = apache-webapplication axis2-webservice echo process nixos-configuration wrapper $(ejabberd_dump) $(mysql_database) $(tomcat_webapplication)

EXTRA_DIST = apache-webapplication axis2-webservice echo ejabberd-dump.in mysql-database.in process nixos-configuration tomcat-webapplication.in wrapper
