AC_PREREQ(2.61)
AC_INIT([disnix-activation-scripts-nixos], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.7.2 -Wall -Werror])

# Change libexecdir
libexecdir=\$\{exec_prefix\}/libexec/disnix/activation-scripts
AC_SUBST(libexecdir)

# Define with options
AC_ARG_WITH([mysql], AS_HELP_STRING([--without-mysql], [Ignore presence of MySQL and disable it]))
AC_ARG_WITH([ejabberd], AS_HELP_STRING([--without-ejabberd], [Ignore presence of ejabberd and disable it]))
AC_ARG_WITH([tomcat], AS_HELP_STRING([--with-tomcat], [Enable Apache Tomcat activation script and specifies location of the Apache Tomcat base directory]))

# Define environment variable options
AC_ARG_WITH(CATALINA_HOME, [Location of the Apache Tomcat Catalina servlet container])

# Checks for programs
AC_PROG_INSTALL

AS_IF([test "x$with_mysql" != "xno"],
      [AC_PATH_PROG(mysql, mysql, [have_mysql=no])],
      [have_mysql=no])

AS_IF([test "x$with_ejabberd" != "xno"],
      [AC_PATH_PROG(ejabberdctl, ejabberdctl, [have_ejabberd=no])],
      [have_ejabberd=no])

AS_IF([test "x$with_tomcat" != "x" || test "x$CATALINA_HOME" != "x"],
      [have_tomcat=yes],
      [have_tomcat=no])

# Set automake conditionals
AM_CONDITIONAL(have_ejabberd, [test x$have_ejabberd != "xno"])
AM_CONDITIONAL(have_mysql, [test x$have_mysql != "xno"])
AM_CONDITIONAL(have_tomcat, [test x$have_tomcat != "xno"])

# CATALINA_BASE setting

AS_IF([test "x$CATALINA_HOME" != "x"],
      [AC_SUBST(CATALINA_BASE, $CATALINA_HOME)],
      [])

AS_IF([test "x$with_tomcat" != "x"],
      [AC_SUBST(CATALINA_BASE, $with_tomcat)],
      [])

# Output

AS_IF([test "x$have_mysql" != "xno"],
      [mysql_database=activation-scripts/mysql-database],
      [])

AS_IF([test "x$have_ejabberd" != "xno"],
      [ejabberd_dump=activation-scripts/ejabberd-dump],
      [])

AS_IF([test "x$have_tomcat" != "xno"],
      [tomcat_webapplication=activation-scripts/tomcat-webapplication],
      [])
      
AC_CONFIG_FILES([
Makefile
activation-scripts/Makefile
$mysql_database
$ejabberd_dump
$tomcat_webapplication
])
AC_OUTPUT
