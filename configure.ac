AC_PREREQ(2.61)
AC_INIT([disnix-activation-scripts-nixos], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.7.2 -Wall -Werror])

# Change libexecdir
libexecdir=\$\{exec_prefix\}/libexec/disnix/activation-scripts
AC_SUBST(libexecdir)

# Define options
AC_ARG_WITH([mysql], AS_HELP_STRING([--without-mysql], [Ignore presence of MySQL and disable it]))
AC_ARG_WITH([ejabberd], AS_HELP_STRING([--without-ejabberd], [Ignore presence of ejabberd and disable it]))

# Checks for programs
AC_PROG_INSTALL

AS_IF([test "x$with_mysql" != "xno"],
      [AC_PATH_PROG(mysql, mysql, [have_mysql=no])],
      [have_mysql=no])

AS_IF([test "x$with_ejabberd" != "xno"],
      [AC_PATH_PROG(ejabberdctl, ejabberdctl, [have_ejabberd=no])],
      [have_ejabberd=no])

# Set automake conditionals
AM_CONDITIONAL(have_ejabberd, [test x$have_ejabberd != "xno"])
AM_CONDITIONAL(have_mysql, [test x$have_mysql != "xno"])

# Output

AS_IF([test "x$have_mysql" != "xno" ],
      [mysql_database=activation-scripts/mysql-database],
      [])

AS_IF([test "x$have_ejabberd" != "xno" ],
      [ejabberd_dump=activation-scripts/ejabberd-dump],
      [])
      
AC_CONFIG_FILES([
Makefile
activation-scripts/Makefile
$mysql_database
$ejabberd_dump
])
AC_OUTPUT
