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

* `apache-webapplication`. Deploys a web application in a document root folder of the [Apache HTTP server](http://httpd.apache.org).
* `axis2-webservice`. Deploys an Axis2 ARchive (AAR) file inside an [Axis2](http://axis2.apache.org) container.
* `echo`. Mereley echos the parameters and environment variables used during activation or deactivation. Useful for debugging purposes.
* `ejabberd-dump`. Deploys an [Ejabberd](http://www.ejabberd.im) configuration database.
* `iis-webapplication`. Deploys a web application in a document root folder of the [Internet Information Services](http://www.iis.net) (IIS) server.
* `mongo-database`. Deploys a [MongoDB](http://www.mongodb.org) database inside a MongoDB DBMS instance.
* `mssql-database`. Deploys a database to a [SQL Server](http://www.microsoft.com/en-us/sqlserver/default.aspx) DBMS instance.
* `mysql-database`. Deploys a database to a [MySQL](http://www.mysql.com) DBMS instance.
* `nixos-configuration`. Deploys a specific [NixOS](http://nixos.org/nixos) configuration.
* `postgresql-database`. Deploys a database to a [PostgreSQL](http://www.postgresql.com) DBMS instance.
* `process`. Wraps a process inside a [systemd](http://www.freedesktop.org/wiki/Software/systemd) or init.d job and activates or deactivates it.
* `subversion-repository`. Deploys [Subversion](http://subversion.apache.org) repository dump into a Subversion working directory.
* `tomcat-webapplication`. Deploys a Java Web Application ARchive (WAR) file inside an [Apache Tomcat](http://tomcat.apache.org) servlet container.
* `wrapper`. Wraps the `bin/wrapper` activation script inside the component into a [systemd](http://www.freedesktop.org/wiki/Software/systemd) or init.d job and activates or deactivates it.

Configuration of the process and wrapper modules
------------------------------------------------
The `process` and `wrapper` modules are supposed to use the host system's
"service manager". Unfortunately, this component differs among operating systems
and system distributions.

By default, Dysnomia is preconfigured to use NixOS' service manager, namely
`systemd`, which expects runtime state files to reside in `/run/systemd` and sets
`/run/current-system/sw/bin` as the default `PATH` for services.

If you are planning to use a different Linux distribution, these settings can be
changed through the `--with-systemd-rundir` and `--with-systemd-path` configure
parameters.

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

    create table author
    ( AUTHOR_ID  INTEGER       NOT NULL,
      FirstName  VARCHAR(255)  NOT NULL,
      LastName   VARCHAR(255)  NOT NULL,
      PRIMARY KEY(AUTHOR_ID)
    );
    
    create table books
    ( ISBN       VARCHAR(255)  NOT NULL,
      Title      VARCHAR(255)  NOT NULL,
      AUTHOR_ID  VARCHAR(255)  NOT NULL,
      PRIMARY KEY(ISBN),
      FOREIGN KEY(AUTHOR_ID) references author(AUTHOR_ID) on update cascade on delete cascade
    );

The folder `~/testdb` represents a logical state dump that we can deploy through
a Dysnomia module.

Providing the container configuration
-------------------------------------
Besides specifying the state of the database, we also need to know to which DBMS
instance (a.k.a. container) we have to deploy a component. The container
settings are captured in a separate container configuration file, such as
`~/mysql-production`:

    type=mysql-database
    mysqlUsername=root
    mysqlPassword=verysecret

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

Deleting older generations of snapshots
---------------------------------------
Dysnomia stores multiple generations of snapshots next to each other and never
automatically deletes them. Instead, it must be done explicitly by the user.

Clearing up older generation of snapshots can be done by invoking the garbage
collect operation. The following command deletes all but the latest snapshot
generation from the Dysnomia snapshots store:

    $ dysnomia-snapshots --gc

The amount of snapshots that must be kept can be adjusted by providing the
`--keep` parameter:

    $ dysnomia-snapshots --gc --keep 3

The above command states that the last 3 generations of snapshots should be
kept.

Implementing custom Dysnomia modules
====================================
Custom Dysnomia modules are relatively easy to implement. Every Dysnomia module
is a process in which the first command-line parameter represents the activity
to execute and the second parameter represents the path to a component
containing a logical state snapshot. The container properties are made available
through environment variables.

The following code fragment shows the source code of the `echo` module, that
simply echoes what it is doing:

    #!/bin/bash
    set -e
    set -o pipefail

    # Activation script that simply echos the service thats being activated or
    # deactivated

    case "$1" in
        # Executes all steps necessary to activate a service. It returns a zero
        # exit status in case of success.
        activate)
            echo "Echo activation script: Activate service: $2"
            ;;
            
        # Executes all steps necessary to deactivate a service. It returns a zero
        # exit status in case of success.
        deactivate)
            echo "Echo activation script: Deactivate service: $2"
            ;;
            
        # Notifies a service that an upgrade is performed. A service can use this to
        # take precautions or to reach quiescence. It can also reject the upgrade by
        # returning a non-zero exit status.
        lock)
            echo "Echo activation script: Lock service: $2"
            ;;
            
        # Notifies a service that an upgrade has finished. A service can use this
        # to resume its normal operations.
        unlock)
            echo "Echo activation script: Unlock service: $2"
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
    esac

    # Print the environment variables

    echo "Environment variables:"
    set

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

    #!/bin/bash
    set -e
    set -o pipefail
    
    # Autoconf settings
    export prefix=@prefix@
    
    # Import utility functions
    source @datadir@/@PACKAGE@/util
    
    determineComponentName $2
    checkStateDir
    determineTypeIdentifier $0
    determineContainerName $3
    composeSnapshotsPath
    composeGarbagePath
    composeGenerationsPath

    case "$1" in
        activate)
            # Initalize the given schema if the database does not exists
            if ! exampleStateInitialized
            then
                exampleInitializeState
            fi
            unmarkStateAsGarbage
            ;;
        deactivate)
            markStateAsGarbage
            ;;
        snapshot)
            tmpdir=$(mktemp -d)
            cd $tmpdir
            exampleSnapshotState | xz > dump.xz
        
            hash=$(cat dump.xz | sha256sum)
            hash=${hash:0:64}
        
            if [ -d $snapshotsPath/$hash ]
            then
                rm -Rf $tmpdir
            else
                mkdir -p $snapshotsPath/$hash
                mv dump.xz $snapshotsPath/$hash
                rmdir $tmpdir
            fi
            createGenerationSymlink $snapshotsPath/$hash
            ;;
        restore)
            determineLastSnapshot
        
            if [ "$lastSnapshot" != "" ]
            then
                exampleRestoreState $lastSnapshot
            fi
            ;;
        collect-garbage)
            if [ -f $garbagePath ]
            then
                exampleDeleteState
                unmarkStateAsGarbage
            fi
            ;;
    esac

The above code fragment outlines an example module implementing deployment
operations of a database:

* `activate`: The activate operation checks whether the database exists in the
   DBMS. If the database does not exists, it gets created and an initial
   static dump (typically a schema) is imported. It also marks the database as
   used so that it will not be removed by the garbage collector.
* `deactivate`: Marks the mutable component (database) as garbage so that it
   will be removed by the garbage collector.
* `snapshot`: Snapshots the database and composes generation symlink determining
   the order of the snapshots. As an optimisation, the module also tries to
   store a snapshot only once. If it has been taken once before, the earlier
   result is reused. To make the optimisation work, a naming convention must be
   chosen. In the above example, the output hash of the snapshot is used.
* `restore`: Determines the last generation snapshot and restores it. If no
   snapshot is in the store, it does nothing.
* `collect-garbage`: Checks if the component is marked as garbage and deletes it
   if this the case. Otherwise, it does nothing.

Dynomia includes a set of utility functions to make implementing these
operations more convenient.

License
=======
This package is released under the [MIT license](http://opensource.org/licenses/MIT).
