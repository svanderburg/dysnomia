AC_PREREQ(2.61)
AC_INIT([dysnomia], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.9 tar-pax -Wall -Werror -Wno-extra-portability])

# Change libexecdir
libexecdir=\$\{exec_prefix\}/libexec/dysnomia
AC_SUBST(libexecdir)

# Define with options
AC_ARG_WITH([apache], AS_HELP_STRING([--with-apache], [Enable Apache HTTP web application script]))
AC_ARG_WITH([axis2], AS_HELP_STRING([--with-axis2], [Enable Apache Axis2 module. Also requires Tomcat enabled]))
AC_ARG_WITH([ejabberd], AS_HELP_STRING([--without-ejabberd], [Ignore presence of ejabberd and disable it]))
AC_ARG_WITH([iis], AS_HELP_STRING([--without-iis], [Ignore presence of Microsoft Internet Information Services]))
AC_ARG_WITH([mssql], AS_HELP_STRING([--without-mssql], [Ignore presence of Microsoft SQL server and disable it]))
AC_ARG_WITH([mysql], AS_HELP_STRING([--without-mysql], [Ignore presence of MySQL and disable it]))
AC_ARG_WITH([postgresql], AS_HELP_STRING([--without-postgresql], [Ignore presence of PostgreSQL and disable it]))
AC_ARG_WITH([mongodb], AS_HELP_STRING([--without-mongodb], [Ignore presence of MongoDB and disable it]))
AC_ARG_WITH([influxdb], AS_HELP_STRING([--without-influxdb], [Ignore presence of InfluxDB and disable it]))
AC_ARG_WITH([tomcat], AS_HELP_STRING([--with-tomcat], [Enable Apache Tomcat module and specifies location of the Apache Tomcat base directory]))
AC_ARG_WITH([subversion], AS_HELP_STRING([--with-subversion], [Enable subversion repository module]))
AC_ARG_WITH([job-template], AS_HELP_STRING([--with-job-template], [Specifies which template to use for the wrapper and process modules. Possible options are: 'systemd' (the default), 'init.d' or 'direct']))
AC_ARG_WITH([systemd-rundir], AS_HELP_STRING([--with-systemd-rundir], [Specifies the state directory of systemd. Defaults to: '/etc/systemd-mutable']))
AC_ARG_WITH([systemd-path], AS_HELP_STRING([--with-systemd-path], [Specifies the path of the composed systemd jobs. Defaults to: '/run/current-system/sw/bin']))
AC_ARG_WITH([sysvinit-initd-dir], AS_HELP_STRING([--with-sysvinit-initd-dir], [Specifies the init.d directory in which sysvinit init scripts are stored. Defaults to: '/etc/init.d']))
AC_ARG_WITH([supervisord], AS_HELP_STRING([--without-supervisord], [Ignore presence of supervisord and disable it]))
AC_ARG_WITH([systemd], AS_HELP_STRING([--without-systemd], [Ignore presence of systemd and disable it]))
AC_ARG_WITH([launchd], AS_HELP_STRING([--without-launchd], [Ignore presence of launchd and disable it]))

# Define environment variable options
AC_ARG_WITH(CATALINA_HOME, [Location of the Apache Tomcat Catalina servlet container])

# Checks for installed programs
AC_DEFUN([NEED_PROG],
[
AC_PATH_PROG($1, $2)
if test -z "$$1"; then
    AC_MSG_ERROR([$2 is required])
fi
])

# Checks for programs
AC_PROG_INSTALL
NEED_PROG(getopt, getopt)
NEED_PROG(readlink, readlink)
AC_PATH_PROG(HELP2MAN, help2man, false)

AS_IF([test "x$with_apache" != "x" && test "x$with_apache" != "xno"],
      [have_apache=yes],
      [have_apache=no])

AS_IF([test "x$with_axis2" != "x" && test "x$with_axis2" != "xno"],
      [have_axis2=yes],
      [have_axis2=no])

AS_IF([test "x$with_ejabberd" != "xno"],
      [AC_PATH_PROG(ejabberdctl, ejabberdctl)])

AS_IF([test "x$with_iis" != "xno"],
      [AC_PATH_PROG(msdeploy, msdeploy)])

AS_IF([test "x$with_mssql" != "xno"],
      [AC_PATH_PROG(osql, osql)])

AS_IF([test "x$with_mysql" != "xno"],
      [AC_PATH_PROG(mysql, mysql)])

AC_PATH_PROG(mysqldump, mysqldump)

AS_IF([test "x$with_postgresql" != "xno"],
      [AC_PATH_PROG(createdb, createdb)])

AS_IF([test "x$with_postgresql" != "xno"],
      [AC_PATH_PROG(psql, psql)])

AC_PATH_PROG(pg_dump, pg_dump)

AS_IF([test "x$with_mongo" != "xno"],
      [AC_PATH_PROG(mongo, mongo)])

AC_PATH_PROG(mongodump, mongodump)
AC_PATH_PROG(mongorestore, mongorestore)

AS_IF([test "x$with_influxdb" != "xno"],
      [AC_PATH_PROG(influx, influx)])

AC_PATH_PROG(influxd, influxd)

AS_IF([test "x$with_subversion" != "xno"],
      [AC_PATH_PROG(svnadmin, svnadmin)])

AS_IF([test "x$with_tomcat" != "x" && test "x$with_tomcat" != "xno" || test "x$CATALINA_HOME" != "x"],
      [have_tomcat=yes],
      [have_tomcat=no])

AS_IF([test "x$with_job_template" = "x"],
      [job_template=systemd],
      [job_template=$with_job_template])

AS_IF([test "x$with_systemd_rundir" = "x"],
      [systemd_rundir=/etc/systemd-mutable],
      [systemd_rundir=$with_systemd_rundir])

AS_IF([test "x$with_systemd_path" = "x"],
      [systemd_path=/run/current-system/sw/bin],
      [systemd_path=$with_systemd_path])

AS_IF([test "x$with_sysvinit_initd_dir" = "x"],
      [sysvinit_initd_dir=/etc/init.d],
      [sysvinit_initd_dir=$sysvinit_initd_dir])

AS_IF([test "x$with_systemd" != "xno"],
      [AC_PATH_PROG(systemctl, systemctl)])

AS_IF([test "x$with_supervisord" != "xno"],
      [AC_PATH_PROG(supervisorctl, supervisorctl)])

AS_IF([test "x$with_launchd" != "xno"],
      [AC_PATH_PROG(launchctl, launchctl)])

# Substitute some variables
AC_SUBST(job_template)
AC_SUBST(systemd_rundir)
AC_SUBST(systemd_path)
AC_SUBST(sysvinit_initd_dir)

# Set automake conditionals
AM_CONDITIONAL(have_apache, [test x$have_apache != "xno"])
AM_CONDITIONAL(have_axis2, [test x$have_axis2 != "xno"])
AM_CONDITIONAL(have_ejabberd, [test x$ejabberdctl != "x"])
AM_CONDITIONAL(have_iis, [test "x$msdeploy" != "x"])
AM_CONDITIONAL(have_mssql, [test "x$osql" != "x"])
AM_CONDITIONAL(have_mysql, [test x$mysql != "x"])
AM_CONDITIONAL(have_postgresql, [test x$psql != "x"])
AM_CONDITIONAL(have_mongodb, [test x$mongo != "x"])
AM_CONDITIONAL(have_influxdb, [test x$influx != "x"])
AM_CONDITIONAL(have_tomcat, [test x$have_tomcat != "xno"])
AM_CONDITIONAL(have_subversion, [test x$svnadmin != "x"])
AM_CONDITIONAL(have_systemd, [test x$systemctl != "x"])
AM_CONDITIONAL(have_supervisord, [test x$supervisorctl != "x"])
AM_CONDITIONAL(have_launchd, [test x$launchctl != "x"])

# CATALINA_BASE setting

AS_IF([test "x$CATALINA_HOME" != "x"],
      [AC_SUBST(CATALINA_BASE, $CATALINA_HOME)])

AS_IF([test "x$with_tomcat" != "x"],
      [AC_SUBST(CATALINA_BASE, $with_tomcat)])

# Output

AS_IF([test "x$have_axis2" != "xno"],
      [axis2_webservice=dysnomia-modules/axis2-webservice])

AS_IF([test "x$msdeploy" != "x"],
      [iis_webapplication=dysnomia-modules/iis-webapplication])

AS_IF([test "x$osql" != "x"],
      [mssql_database=dysnomia-modules/mssql-database])

AS_IF([test "x$mysql" != "x"],
      [mysql_database=dysnomia-modules/mysql-database])

AS_IF([test "x$psql" != "x"],
      [postgresql_database=dysnomia-modules/postgresql-database])

AS_IF([test "x$mongo" != "x"],
      [mongo_database=dysnomia-modules/mongo-database])

AS_IF([test "x$influx" != "x"],
      [influx_database=dysnomia-modules/influx-database])

AS_IF([test "x$ejabberdctl" != "x"],
      [ejabberd_dump=dysnomia-modules/ejabberd-dump])

AS_IF([test "x$have_tomcat" != "xno"],
      [tomcat_webapplication=dysnomia-modules/tomcat-webapplication])

AS_IF([test "x$svnadmin" != "x"],
      [subversion_repository=dysnomia-modules/subversion-repository])

AS_IF([test "x$systemctl" != "x"],
      [systemd_unit=dysnomia-modules/systemd-unit])

AS_IF([test "x$supervisorctl" != "x"],
      [supervisord_program=dysnomia-modules/supervisord-program])

AS_IF([test "x$launchctl" != "x"],
      [launchd_daemon=dysnomia-modules/launchd-daemon])

AC_CONFIG_FILES([
Makefile
scripts/dysnomia
scripts/dysnomia-containers
scripts/dysnomia-snapshots
scripts/Makefile
dysnomia-modules/apache-webapplication
dysnomia-modules/nixos-configuration
dysnomia-modules/fileset
dysnomia-modules/process
dysnomia-modules/wrapper
dysnomia-modules/sysvinit-script
dysnomia-modules/Makefile
data/Makefile
nix/Makefile
$axis2_webservice
$ejabberd_dump
$iis_webapplication
$mssql_database
$mysql_database
$postgresql_database
$mongo_database
$influx_database
$tomcat_webapplication
$subversion_repository
$systemd_unit
$supervisord_program
$launchd_daemon
])
AC_OUTPUT
