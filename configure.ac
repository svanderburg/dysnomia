AC_PREREQ(2.61)
AC_INIT([dysnomia], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.7.2 -Wall -Werror -Wno-extra-portability])

# Change libexecdir
libexecdir=\$\{exec_prefix\}/libexec/dysnomia
AC_SUBST(libexecdir)

# Define with options
AC_ARG_WITH([apache], AS_HELP_STRING([--with-apache], [Enable Apache HTTP web application script]))
AC_ARG_WITH([axis2], AS_HELP_STRING([--with-axis2], [Enable Apache Axis2 activation script. Also requires Tomcat enabled]))
AC_ARG_WITH([ejabberd], AS_HELP_STRING([--without-ejabberd], [Ignore presence of ejabberd and disable it]))
AC_ARG_WITH([iis], AS_HELP_STRING([--without-iis], [Ignore presence of Microsoft Internet Information Services]))
AC_ARG_WITH([mssql], AS_HELP_STRING([--without-mssql], [Ignore presence of Microsoft SQL server and disable it]))
AC_ARG_WITH([mysql], AS_HELP_STRING([--without-mysql], [Ignore presence of MySQL and disable it]))
AC_ARG_WITH([postgresql], AS_HELP_STRING([--without-postgresql], [Ignore presence of PostgreSQL and disable it]))
AC_ARG_WITH([mongodb], AS_HELP_STRING([--without-mongodb], [Ignore presence of MongoDB and disable it]))
AC_ARG_WITH([tomcat], AS_HELP_STRING([--with-tomcat], [Enable Apache Tomcat activation script and specifies location of the Apache Tomcat base directory]))
AC_ARG_WITH([subversion], AS_HELP_STRING([--with-subversion], [Enable subversion repository activation script]))
AC_ARG_WITH([job-template], AS_HELP_STRING([--with-job-template], [Specifies which template to use for the wrapper and process modules. Possible options are: 'systemd' (the default) or 'init.d']))

# Define environment variable options
AC_ARG_WITH(CATALINA_HOME, [Location of the Apache Tomcat Catalina servlet container])

# Checks for programs
AC_PROG_INSTALL

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

AS_IF([test "x$with_postgresql" != "xno"],
      [AC_PATH_PROG(createdb, createdb)])

AS_IF([test "x$with_postgresql" != "xno"],
      [AC_PATH_PROG(psql, psql)])

AS_IF([test "x$with_mongo" != "xno"],
      [AC_PATH_PROG(mongo, mongo)])

AS_IF([test "x$with_subversion" != "xno"],
      [AC_PATH_PROG(svnadmin, svnadmin)])

AS_IF([test "x$with_tomcat" != "x" && test "x$with_tomcat" != "xno" || test "x$CATALINA_HOME" != "x"],
      [have_tomcat=yes],
      [have_tomcat=no])

AS_IF([test "x$with_job_template" = "x"],
      [job_template=systemd],
      [job_template=$with_job_template])

# Substitute some variables
AC_SUBST(job_template)

# Set automake conditionals
AM_CONDITIONAL(have_apache, [test x$have_apache != "xno"])
AM_CONDITIONAL(have_axis2, [test x$have_axis2 != "xno"])
AM_CONDITIONAL(have_ejabberd, [test x$ejabberdctl != "x"])
AM_CONDITIONAL(have_iis, [test "x$msdeploy" != "x"])
AM_CONDITIONAL(have_mssql, [test "x$osql" != "x"])
AM_CONDITIONAL(have_mysql, [test x$mysql != "x"])
AM_CONDITIONAL(have_postgresql, [test x$psql != "x"])
AM_CONDITIONAL(have_mongodb, [test x$mongo != "x"])
AM_CONDITIONAL(have_tomcat, [test x$have_tomcat != "xno"])
AM_CONDITIONAL(have_subversion, [test x$svnadmin != "x"])

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

AS_IF([test "x$ejabberdctl" != "x"],
      [ejabberd_dump=dysnomia-modules/ejabberd-dump])

AS_IF([test "x$have_tomcat" != "xno"],
      [tomcat_webapplication=dysnomia-modules/tomcat-webapplication])

AS_IF([test "x$svnadmin" != "x"],
      [subversion_repository=dysnomia-modules/subversion-repository])

AC_CONFIG_FILES([
Makefile
scripts/dysnomia
scripts/Makefile
dysnomia-modules/process
dysnomia-modules/wrapper
dysnomia-modules/Makefile
doc/Makefile
doc/man/Makefile
data/Makefile
$axis2_webservice
$ejabberd_dump
$iis_webapplication
$mssql_database
$mysql_database
$postgresql_database
$mongo_database
$tomcat_webapplication
$subversion_repository
])
AC_OUTPUT
