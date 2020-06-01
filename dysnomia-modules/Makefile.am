# Build settings

libexec_SCRIPTS = echo fileset nixos-configuration managed-process

# Append optional modules

if !enable_legacy
    libexec_SCRIPTS += process wrapper
endif

if LINUX
    libexec_SCRIPTS += sysvinit-script
endif

if BSD
    libexec_SCRIPTS += bsdrc-script
endif

if have_apache
    libexec_SCRIPTS += apache-webapplication
endif

if have_axis2
    libexec_SCRIPTS += axis2-webservice
endif

if have_ejabberd
    libexec_SCRIPTS += ejabberd-dump
endif

if have_iis
    libexec_SCRIPTS += iis-webapplication
endif

if have_mssql
    libexec_SCRIPTS += mssql-database
endif

if have_mysql
    libexec_SCRIPTS += mysql-database
endif

if have_postgresql
    libexec_SCRIPTS += postgresql-database
endif

if have_tomcat
    libexec_SCRIPTS += tomcat-webapplication
endif

if have_subversion
    libexec_SCRIPTS += subversion-repository
endif

if have_mongodb
    libexec_SCRIPTS += mongo-database
endif

if have_influxdb
    libexec_SCRIPTS += influx-database
endif

if have_systemd
    libexec_SCRIPTS += systemd-unit
endif

if have_supervisord
    libexec_SCRIPTS += supervisord-program
endif

if have_launchd
    libexec_SCRIPTS += launchd-daemon
endif

if have_cygrunsrv
    libexec_SCRIPTS += cygrunsrv-service
endif

pkgdata_SCRIPTS = util

EXTRA_DIST = apache-webapplication.in \
	axis2-webservice.in \
	bsdrc-script.in \
	cygrunsrv-service.in \
	echo \
	ejabberd-dump.in \
	fileset.in \
	iis-webapplication.in \
	influx-database.in \
	launchd-daemon.in \
	managed-process.in \
	mongo-database.in \
	mssql-database.in \
	mysql-database.in \
	nixos-configuration.in \
	postgresql-database.in \
	process.in \
	subversion-repository.in \
	supervisord-program.in \
	systemd-unit.in \
	sysvinit-script.in \
	tomcat-webapplication.in \
	util \
	wrapper.in

SUBDIRS = legacy
