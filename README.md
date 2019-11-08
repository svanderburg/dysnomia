Dysnomia
========
Dysnomia is a tool and plug-in system that can be used to automatically deploy
*mutable components*. It is primarily designed to be used in combination with
[Disnix](http://nixos.org/disnix) for activation and deactivation of services,
but it can also be used as a seperate utility.

Mutable components
==================
When deploying software systems, most of its components are static or immutable,
such as end-user programs, development tools, and servers. These components can
be deployed (apart from their state files) on a read-only filesystem and never
change after they have been built.

For example, the [Nix package manager](http://nixos.org/nix), which is used as
a basis for local deployment in Disnix, achieves many of its quality attributes
from immutability, such as reliable and reproducible deployment. Moreover, each
time Nix deploys a new version or variant of a component it is stored next to an
older version or variant. After a component has deployed, it is usually
sufficient to launch it from the command-line or program launcher menu from the
desktop.

However, to fully automate deployment procedures for certain kinds of systems,
we also need to deploy components that cannot be managed in such a deployment
model, such as databases and source code repositories, because it is too costly
to store multiple generations of them next to each other.

Moreover, mutable components may also have to be activated (or deactivated) in
so-called containers, such as application servers, managing the resources of an
application. These procedures cannot be executed generically, as they are
specific to the type of container that is used.

Mutable components are components with the following characteristics:

* Their state may change _imperatively_ over time.
* They may have to be activated or deactivated in a _container_ before they can
  be used. To do this, the _state_ of a container must be modified.
* The have a physical state and _logical_ representation of the state, which is
  typically a dump taken at a certain moment in a portable/consistent way.

Installation
============
Installation of Dysnomia is very straight forward by running the standard
Autotools build procedure:

    $ ./configure
    $ make
    $ make install

The Dysnomia package contains a collection of Dysnomia modules capable of
executing the deployment steps for certain types of mutable components. The
`configure` script tries to automatically detect which ones the system is able
to support, by looking at the presence of certain command-line utilities and
files.

It is also possible to disable certain Dysnomia modules or to tune the
configuration parameters. More information on this can be found by running:

    $ ./configure --help

Dysnomia modules
================
The Dysnomia package contains the following modules, of which some of them can
be optionally enabled/disabled:

* `apache-webapplication`. Deploys a web application in a document root folder
  of the [Apache HTTP server](http://httpd.apache.org).
* `axis2-webservice`. Deploys an Axis2 ARchive (AAR) file inside an
  [Axis2](http://axis2.apache.org) container.
* `echo`. Mereley echos the parameters and environment variables used during
  activation or deactivation. Useful for debugging purposes.
* `ejabberd-dump`. Deploys an [Ejabberd](http://www.ejabberd.im) configuration
  database.
* `fileset`. Deploys a directory on the filesystem that is populated with
  static/immutable and dynamic/mutable files.
* `iis-webapplication`. Deploys a web application in a document root folder of
  the [Internet Information Services](http://www.iis.net) (IIS) server.
* `mongo-database`. Deploys a [MongoDB](http://www.mongodb.org) database inside
  a MongoDB DBMS instance.
* `mssql-database`. Deploys a database to a
  [SQL Server](http://www.microsoft.com/en-us/sqlserver/default.aspx) DBMS
  instance.
* `mysql-database`. Deploys a database to a [MySQL](http://www.mysql.com) DBMS
  instance.
* `influx-database`. Deploys a timeseries database to a
  [InfluxDB](https://www.influxdata.com) server instance.
* `nixos-configuration`. Deploys a specific [NixOS](http://nixos.org/nixos)
  configuration.
* `postgresql-database`. Deploys a database to a
  [PostgreSQL](http://www.postgresql.com) DBMS instance.
* `process`. Wraps a process inside a
  [systemd](http://www.freedesktop.org/wiki/Software/systemd) or init.d job and
  activates or deactivates it.
* `subversion-repository`. Deploys [Subversion](http://subversion.apache.org)
  repository dump into a Subversion working directory.
* `tomcat-webapplication`. Deploys a Java Web Application ARchive (WAR) file
  inside an [Apache Tomcat](http://tomcat.apache.org) servlet container.
* `wrapper`. Wraps the `bin/wrapper` activation script inside the component into
  a [systemd](http://www.freedesktop.org/wiki/Software/systemd) or init.d job
  and activates or deactivates it.
* `sysvinit-script` activates or deactivates a sysvinit script

Configuration of the process and wrapper modules
------------------------------------------------
The `process` and `wrapper` modules are supposed to use the host system's
"service manager". Unfortunately, this component differs among operating systems
and system distributions.

By default, Dysnomia is preconfigured to use NixOS' service manager, namely
`systemd`, which expects runtime state files to reside in
`/etc/systemd-mutable/system` and sets `/run/current-system/sw/bin` as the
default `PATH` for services.

If you are planning to use a different Linux distribution, these settings can be
changed through the `--with-systemd-rundir` and `--with-systemd-path` configure
parameters.

`systemd` jobs deployed by Dysnomia are wanted by the `dysnomia.target`, if this
file exists. However, this target file is not created by default. You need to do
this yourself first. The following command typically suffices:

```bash
$ cat > /etc/systemd-mutable/system/dysnomia.target <<EOF
[Unit]
Description=Services that are activated and deactivated by Dysnomia
After=final.target
EOF
```

Apart from `systemd`, Dysnomia can also be used to generate plain old `init.d`
scripts instead. The template that is used to generate these scripts reside in
`data/*.template.initd` of the source distribution. By default, it's configured
to generate an `init.d` script for Ubuntu 12.04 LTS.

If none of the operating system's service manager can be used, Dysnomia can also
activate and deactivate services directly. To accomplish this use the `direct`
template option.

To support other kinds of Linux distributions, you need to adapt these templates
to match your distribution's convention.

Usage
=====
In order to use Dysnomia to deploy mutable components, we require two kinds of
dependencies:

* A component containing a logical snapshot of the initial state of a mutable component
* A configuration file capturing properties of the container in which the component must be deployed

Providing a logical state snapshot of the component
---------------------------------------------------
The following file could be stored in `~/testdb/mysql-database/createdb.sql`
representing the logical state of a MySQL database. In this particular case, this
file is a collection of SQL statements setting up the initial schema of the
database:

```sql
create table author
( AUTHOR_ID  INTEGER       NOT NULL,
  FirstName  VARCHAR(255)  NOT NULL,
  LastName   VARCHAR(255)  NOT NULL,
  PRIMARY KEY(AUTHOR_ID)
);

create table books
( ISBN       VARCHAR(255)  NOT NULL,
  Title      VARCHAR(255)  NOT NULL,
  AUTHOR_ID  INTEGER       NOT NULL,
  PRIMARY KEY(ISBN),
  FOREIGN KEY(AUTHOR_ID) references author(AUTHOR_ID) on update cascade on delete cascade
);
```

The folder `~/testdb` represents a logical state dump that we can deploy through
a Dysnomia module.

Providing the container configuration
-------------------------------------
Besides specifying the state of the database, we also need to know to which DBMS
instance (a.k.a. container) we have to deploy a component. The container
settings are captured in a separate container configuration file, such as
`~/mysql-production`:

```bash
type=mysql-database
mysqlUsername=root
mysqlPassword=verysecret
```

The above file is a very simple textual configuration files consisting of
key=value pairs. The `type` property is the only setting that is mandatory,
because it is used to invoke the corresponding Dysnomia module that takes care
of the deployment operations for that container. The remaining properties are
used by the particular Dysnomia module.

Executing a deployment activity
-------------------------------
With those two files, we can perform a deployment activity, such as activating a
MySQL database inside a MySQL DBMS instance:

    $ dysnomia --operation activate --component ~/testdb --container ~/mysql-production

Every component has its own way of representing its logical state and each of
them require different container settings. For databases, these are typically SQL
dumps and authentication settings.

Web applications have archive files (WAR/AAR) or a collection of web related
files (HTML, CSS etc.) as a representation of their logical state. Consult the
actual Dysnomia modules for more information.

Managing snapshots
------------------
Dysnomia can also be used to manage snapshots of mutable components. Running the
following operation captures the state of a deployed MySQL database:

    $ dysnomia --operation snapshot --component ~/testdb --container ~/mysql-production

Restoring the last taken snapshot can be done by running:

    $ dysnomia --operation restore --component ~/testdb --container ~/mysql-production

Snapshots taken by Dysnomia are stored in a so-called Dysnomia snapshot store
(stored by default in `/var/state/dysnomia`, but can be changed by setting the
`DYSNOMIA_STATEDIR` environment variable), a special purpose directory that
stores multiple generations of snapshots according to some naming convention
that uniquely identifies each snapshot.

The following command can be used to query all snapshots taken for the component
`testdb` deployed to the MySQL container.

    $ dysnomia-snapshots --query-all --container mysql-database --component testdb
    mysql-production/testdb/9b0c3562b57dafd00e480c6b3a67d29146179775b67dfff5aa7a138b2699b241
    mysql-production/testdb/1df326254d596dd31d9d9db30ea178d05eb220ae51d093a2cbffeaa13f45b21c
    mysql-production/testdb/330232eda02b77c3629a4623b498855c168986e0a214ec44f38e7e0447a3f7ef

In most cases, only the latest snapshot is useful. The following query only
shows the last generation snapshot:

    $ dysnomia-snapshots --query-latest --container mysql-production --component testdb
    mysql-production/testdb/330232eda02b77c3629a4623b498855c168986e0a214ec44f38e7e0447a3f7ef

The query operations show the relative paths of the snapshot directories so that
their names are consistent among multiple machines. Their absolute paths can be
resolved by running:

    $ dysnomia-snapshots --resolve mysql-database/testdb/330232eda02b77c3629a4623b498855c168986e0a214ec44f38e7e0447a3f7ef
    /var/state/dysnomia/snapshots/mysql-production/testdb/330232eda02b77c3629a4623b498855c168986e0a214ec44f38e7e0447a3f7ef

Every container type follows its own naming convention that uniquely identifies a
snapshot. For example, for MySQL databases a snapshot is identified by its
output hash, such as `9b0c3562b57dafd00e480c6b3a67d29146179775b67dfff5aa7a138b2699b241`.

Using a specific naming convention (e.g. computing an output hash) has all kinds
of advantanges. For example, if we take a snapshot twice and they happen to be
the same (which is reflected in the output hash), we only have to store the
result once.

Not all component types use output hashes as a naming convention. For example,
for Subversion repositories the revision number is used. Besides reducing storage
redundancy this convention has another advantage -- when restoring a snapshot,
we can first check whether the repository is at the right revision. There is no
need to restore a snapshot if the revision number equals the revision number of
a snapshot.

Checking the integrity of snapshots
-----------------------------------
In addition to querying the available snapshots, it is also possible to check
their integrity to detect whether they have been corrupted or not.

By running a query operation and adding the `--check` parameter, the integrity
of the corresponding snapshots can be checked. For example, the following
command checks the integrity of all MySQL database snapshots in the store:

    $ dysnomia-snapshots --query-all --check --container mysql-database

Deleting the state of components
--------------------------------
Apart from snapshotting and restoring the state of mutable components, it may
also be desirable to delete state, such as removing a database.

To remove state, first a component must be deactivated:

    $ dysnomia --operation deactivate --component ~/testdb --container ~/mysql-production

The above operation does not delete the database. Instead, it simply marks it as
garbage, but otherwise keeps it. Actually deleting the database can be done by
invoking the garbage collect operation:

    $ dysnomia --operation collect-garbage --component ~/testdb --container ~/mysql-production

The above command first checks whether the database has been marked as garbage.
If this is the case (because it has been deactivated) it is dropped. Otherwise,
this command does nothing (because we do not want to delete stuff that is
actually in use).

Deleting older generations of snapshots
---------------------------------------
Dysnomia stores multiple generations of snapshots next to each other and also
never automatically deletes them. Instead, it must be done explicitly by the
user.

Clearing up older generation of snapshots can be done by invoking the garbage
collect operation. The following command deletes all but the latest snapshot
generation from the Dysnomia snapshots store:

    $ dysnomia-snapshots --gc

The amount of snapshots that must be kept can be adjusted by providing the
`--keep` parameter:

    $ dysnomia-snapshots --gc --keep 3

The above command states that the last 3 generations of snapshots should be
kept.

Spawning a shell session for arbitrary maintenance or debugging tasks
---------------------------------------------------------------------
When incidents occur and it is desired to debug or execute arbitrary maintenance
tasks, it can be somewhat annoying to manually configure all properties so that
we connect to a component deployed to a container.

The Dysnomia shell can be used to spawn a session in which the environment
variables are configured to contain the container's configuration properties:

    $ dysnomia --shell --component ~/testdb --container ~/mysql-production

In addition to a shell session that contains a container configuration
properties, a Dysnomia module also typically displays command-line tool
suggestions to the user executing common housekeeping tasks.

Managing collections of containers
==================================
Besides executing operations on individual mutable components, we can also
manage sets of containers (and their corresponding mutable components) in one go
through the `dysnomia-containers` utility.

Executing operations on collections of containers
-------------------------------------------------
The following command shows all the available containers to deploy to:

    $ dysnomia-containers --query-containers
    mysql-database
    postgresql-database

The above command searches for container configuration files in the directories
provided by the `DYSNOMIA_CONTAINERS_PATH` environment variable (which defaults
to: `/etc/dysnomia/containers`).

We can also display all the available mutable components:

    $ dysnomia-containers --query-available-components
    mysql-database/testdb
    postgresql-database/testdb

The above command searches for component configuration files in the directories
provided by the `DYSNOMIA_COMPONENTS_PATH` environment variable (which defaults
to: `/etc/dysnomia/components`). Optionally, you can filter the output per
container by providing the `--container` parameter.

The following command shows all components that have been activated in a
container:

    $ dysnomia-containers --query-activated-components

The most useful operation is probably the deploy function:

    $ dysnomia-containers --deploy

The above command will automatically deploy all available mutable components
that have not been activated yet, and will undeploy all activated components
that are not available anymore. This command automates the deactivation and
activation steps of collections of components.

We can also snapshot the state of all activated components:

    $ dysnomia-containers --snapshot

and restore the state of them:

    $ dysnomia-containers --restore

The following command removes the state of all components that have been marked
as garbage:

    $ dysnomia-containers --collect-garbage

We can also directly execute any Dysnomia operation on all activated components:

    $ dysnomia-containers --operation snapshot

Generating a Nix configuration file of the container configurations
-------------------------------------------------------------------
It is also possible to generate a Nix expression capturing the properties of all
the container configurations, by running:

    $ dysnomia-containers --generate-expr

The above command shows a generated Nix expression that may look as follows:

```nix
{
  properties = {
    "hostname" = "test1";
    "mem" = "1023096";
    "supportedTypes" = [
      "mysql-database"
      "process"
      "tomcat-webapplication"
    ];
    "system" = "x86_64-linux";
  };
  containers = {
    mysql-database = {
      "mysqlPassword" = "admin";
      "mysqlPort" = "3306";
      "mysqlUsername" = "root";
    };
    tomcat-webapplication = {
      "tomcatPort" = "8080";
    };
  };
}
```

The generated expression is an attribute set exposing two attributes. The
`containers` attribute is composed of all container configuration files in the
`DYSNOMIA_CONTAINERS_PATH` environment variable.

The `properties` attribute contains non-functional machine-level properties
that can be freely chosen. These are takes from the `/etc/dysnomia/properties`
configuration file or the file to which the `DYSNOMIA_PROPERTIES` environment
variable refers.

For example, the above machine properties are generated from the following
configuration file:

```bash
hostname="$(hostname)"
mem=$(grep 'MemTotal:' /proc/meminfo | sed -e 's/kB//' -e 's/MemTotal://' -e 's/ //g')
supportedTypes=("mysql-database" "process" "tomcat-webapplication")
system="x86_64-linux"
```

The Nix expression output generated by `dysnomia-containers --generate-expr`
makes it convenient to integrate Dysnomia with various Nix-driven utilities,
such as `disnix-capture-infra` (part of Disnix) and the
[Dynamic Disnix Avahi publisher](https://github.com/svanderburg/dydisnix-avahi).

NixOS integration
=================
In addition to Disnix, it is also possible to use Dysnomia on NixOS-level to
automatically manage mutable components belonging to a system configuration:

```nix
{pkgs, ...}:

{
  # Import the Dysnomia NixOS module to make its functionality available
  imports = [ ./dysnomia-module.nix ];
  
  services = {
    # Enabling MySQL in the NixOS configuration implies creating a Dysnomia
    # container configuration file for it
    
    mysql = {
      enable = true;
      package = pkgs.mysql;
      rootPassword = pkgs.writeTextFile {
        name = "mysqlpw";
        text = "verysecret";
      };
    };
    
    # Enabling PostgreSQL in the NixOS configuration implies creating a
    # Dysnomia container configuration file for it
    
    postgresql = {
      enable = true;
      package = pkgs.postgresql;
    };
    
    dysnomia = {
      enable = true;
      
      # Here, we deploy databases to the corresponding DBMSes with Dysnomia
      components = {
        mysql-database = {
          testdb = pkgs.writeTextFile {
            name = "testdb";
            text = ''
              create table author
              ( AUTHOR_ID  INTEGER       NOT NULL,
                FirstName  VARCHAR(255)  NOT NULL,
                LastName   VARCHAR(255)  NOT NULL,
                PRIMARY KEY(AUTHOR_ID)
              );
            '';
          };
        };
        
        postgresql-database = {
          testdb = pkgs.writeTextFile {
            name = "testdb";
            text = ''
              create table author
              ( AUTHOR_ID  INTEGER       NOT NULL,
                FirstName  VARCHAR(255)  NOT NULL,
                LastName   VARCHAR(255)  NOT NULL,
                PRIMARY KEY(AUTHOR_ID)
              );
            '';
          };
        };
      };
    };
    
    ...
}
```

The above code block shows an example NixOS configuration, in which we do the
following:

* We import the Dysnomia module from the source package to make its
  features available.
* We enable the Dysnomia NixOS service
* We enable some system services, such as MySQL and PostgreSQL. The Dysnomia
  NixOS module automatically generates Dysnomia container configuration files
  for them (and puts them in `/etc/dysnomia/containers` of the corresponding
  NixOS deployment)
* We define the available mutable components. In this particular example, a
  MySQL database named `testdb` and PostgreSQL database named `testdb` which
  both have one table named: `author` are created.

After deploying the NixOS configuration with the following command-line
instruction:

    $ nixos-rebuild switch

We can deploy the mutable components as follows:

    $ dysnomia-containers --deploy

And (for example) snapshot the state of the mutable components as follows:

    $ dysnomia-containers --snapshot

To prevent the state of the mutable components to conflict with those deployed
by Disnix, the Dysnomia module sets `DYSNOMIA_STATEDIR` to
`/var/state/dysnomia-nixos` so that they are managed separately.

Implementing custom Dysnomia modules
====================================
Custom Dysnomia modules are relatively easy to implement. Every Dysnomia module
is a process in which the first command-line parameter represents the activity
to execute and the second parameter represents the path to a component
containing a logical state snapshot. The container properties are made available
through environment variables.

The following code fragment shows the source code of the `echo` module, that
simply echoes what it is doing:

```bash
#!/bin/bash
set -e
set -o pipefail

# Dysnomia module that simply echos the activity that is being executed.

case "$1" in
    # Executes all steps necessary to activate a service. It returns a zero
    # exit status in case of success.
    activate)
        echo "Echo module: Activate service: $2"
        ;;
        
    # Executes all steps necessary to deactivate a service. It returns a zero
    # exit status in case of success.
    deactivate)
        echo "Echo module: Deactivate service: $2"
        ;;
        
    # Notifies a service that an upgrade is performed. A service can use this to
    # take precautions or to reach quiescence. It can also reject the upgrade by
    # returning a non-zero exit status.
    lock)
        echo "Echo module: Lock service: $2"
        ;;
        
    # Notifies a service that an upgrade has finished. A service can use this
    # to resume its normal operations.
    unlock)
        echo "Echo module: Unlock service: $2"
        ;;
    
    # Snapshots the corresponding state of the service in a preferably consistent
    # and portable manner in a special purpose folder with a naming strategy.
    snapshot)
        echo "Echo module: Snapshot state of service: $2"
        ;;
    
    # Restores the state of the service from the special purpose folder with a
    # naming strategy.
    restore)
        echo "Echo module: Restore state of service: $2"
        ;;
    
    # Collects the garbage of the service by permanently removing it
    collect-garbage)
        echo "Echo module: Collect garbage of service: $2"
        ;;

    # Script that gets executed when spawning a shell session. It is typically
    # used to provide usage instructions to the user.
    shell)
        echo "This is the echo shell session"
        ;;
esac

# Print the environment variables

echo "Environment variables:"
set
```

Currently, Dysnomia supports the following types of operations:

* `activate` is used to activate the component in a container.
* `deactivate` is used to deactivate the component in a container.
* `lock` is invoked by Disnix before the upgrade transition starts. This
   operation can be used to consult a deployed component to determine whether it
   is safe to upgrade and to take precautions before the upgrade starts (such as
   queing incoming connections).
* `unlock` is invoked by Disnix after the upgrade transition is over. This can
   be used to notify the component to resume its normal operations.
* `snapshot` is used to snapshot the logical state of a component in a
   container. This operation is optionally executed by Disnix to move data from
   one machine to another.
* `restore` is used to restore the logical state of a component in a container.
   This operation is optionally executed by Disnix to move data from one machine
   to another.
* `collect-garbage` is used to remove the state of a component in a container.

The above code examples are written in [bash](http://www.gnu.org/software/bash),
but any lanugage can be used as long as the tool provides the same command-line
interface and properly uses the environment variables from the container
specification.

Convention for stateful mutable components
------------------------------------------
The implementation of each operation is completely the responsible of the
implementer. However, for mutable components with persistent state, such as
databases, we typically follow a convention for many of the operations:

```bash
#!/bin/bash
set -e
set -o pipefail

# Autoconf settings
export prefix=@prefix@

# Import utility functions
source @datadir@/@PACKAGE@/util

# Sets a number of common utility environment variables
composeUtilityVariables $0 $2 $3

case "$1" in
    activate)
        # Initalize the given schema if the database does not exists
        if ! exampleStateInitialized
        then
            exampleInitializeState
        fi
        markComponentAsActive
        ;;
    deactivate)
        markComponentAsGarbage
        ;;
    snapshot)
        # Dump the state of the component in a temp dir
        tmpdir=$(mktemp -d)
        cd $tmpdir
        exampleSnapshotState | xz > dump.xz

        # Compose a unique name for the snapshot
        hash=$(cat dump.xz | sha256sum)
        hash=${hash:0:64}

        snapshotsPath=$(composeSnapshotsPath)

        if [ -d $snapshotsPath/$hash ]
        then
            # If the snapshot exists in the store already, discard it
            rm -Rf $tmpdir
        else
            # Import the snapshot into the snapshot store
            mkdir -p $snapshotsPath/$hash
            mv dump.xz $snapshotsPath/$hash
            rmdir $tmpdir
        fi
        
        # Create a generation symlink for the snapshot
        createGenerationSymlink $hash
        ;;
    restore)
        lastSnapshot=$(determineLastSnapshot)

        if [ "$lastSnapshot" != "" ]
        then
            exampleRestoreState $lastSnapshot
        fi
        ;;
    collect-garbage)
        if componentMarkedAsGarbage
        then
            exampleDeleteState
            unmarkComponentAsGarbage
        fi
        ;;
    shell)
        cat >&2 <<EOF
This is a shell session that can be used to control the '$componentName' database.
EOF
        ;;
esac
```

The above code fragment outlines an example module implementing deployment
operations of a database:

* `activate`: The activate operation checks whether the database exists in the
   DBMS. If the database does not exists, it gets created and an initial
   static dump (typically a schema) is imported. It also marks the database as
   active so that it will not be removed by the garbage collector.
* `deactivate`: Marks the mutable component (database) as garbage so that it
   will be removed by the garbage collector.
* `snapshot`: Snapshots the database and composes generation symlink determining
   the order of the snapshots. As an optimisation, the module also tries to
   store a snapshot only once. If it has been taken once before, the earlier
   result is reused. To make the optimisation work, a naming convention must be
   chosen. In the above example, the output hash of the snapshot is used.
* `restore`: Determines the last generation snapshot and restores it. If no
   snapshot is in the store, it does nothing.
* `collect-garbage`: Checks if the component is not deployed to a container and
   deletes it if this the case. Otherwise, it does nothing.

Dynomia includes a set of utility functions to make implementing these
operations more convenient.

Container and component configuration properties
------------------------------------------------
Each module takes its own container and component configuration properties. Both
are exposed as environment variables. Consult the documentation inside the
modules (stored in the `dysnomia-modules/` sub folder of this package) for more
information.

License
=======
This package is released under the [MIT license](http://opensource.org/licenses/MIT).
