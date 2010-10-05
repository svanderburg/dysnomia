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

if have_mysql
    mysql_database = mysql-database
endif

if have_tomcat
    tomcat_webapplication = tomcat-webapplication
endif


# Build settings

libexec_SCRIPTS = echo process nixos-configuration wrapper $(apache_webapplication) $(axis2_webservice) $(ejabberd_dump) $(mysql_database) $(tomcat_webapplication)

EXTRA_DIST = apache-webapplication axis2-webservice.in echo ejabberd-dump.in mysql-database.in process nixos-configuration tomcat-webapplication.in wrapper
