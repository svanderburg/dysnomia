AC_PREREQ(2.61)
AC_INIT([disnix-activation-scripts-nixos], [0.1])
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.7.2 -Wall -Werror])

# Change libexecdir
libexecdir=\$\{exec_prefix\}/libexec/$PACKAGE/activation-scripts
AC_SUBST(libexecdir)

# Checks for programs
AC_PROG_INSTALL

# Output
AC_CONFIG_FILES([
Makefile
activation-scripts/Makefile
])
AC_OUTPUT
