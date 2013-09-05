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
from this fact, such as reliable and reproducible deployment. Moreover, each time
Nix deploys a new version or variant of a component it is stored next to an older
version or variant. After a component has deployed, it is usually sufficient to
launch it from the command-line or program launcher menu from the desktop.

However, to fully automate deployment procedures for certain kinds of systems,
we also need to deploy components that cannot be managed in such a deployment
model, such as databases and source code repositories, because it is too costly
to store multiple generations next to each other.

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

* `apache-webapplication`. Activates or deactivates a web application in a document root folder of the [Apache HTTP server](http://httpd.apache.org).
* `axis2-webservice`. Activates or deactivates an Axis2 ARchive (AAR) file inside an [Axis2](http://axis2.apache.org) container.
* `echo`. Mereley echos the parameters and environment variables used during activation or deactivation. Useful for debugging purposes.
* `ejabberd-dump`. Activates or deactivates an [Ejabberd](http://www.ejabberd.im) configuration database.
* `iis-webapplication`. Activates or deactivates a web application in a document root folder of the [Internet Information Services](http://www.iis.net) (IIS) server.
* `mssql-database`. Imports a database dump inside a [SQL Server](www.microsoft.com/en-us/sqlserver/default.aspx) DBMS instance.
* `mysql-database`. Imports a database dump inside a [MySQL](http://www.mysql.com) DBMS instance.
* `nixos-configuration`. Activates a specific [NixOS](http://nixos.org/nixos) configuration.
* `postgresql-database`. Imports a database dump inside a [PostgreSQL](http://www.postgresql.com) DBMS instance.
* `process`. Wraps a process inside a [systemd](http://www.freedesktop.org/wiki/Software/systemd) job and activates or deactivates it.
* `subversion-repository`. Imports a Subversion repository dump into a Subversion working directory.
* `tomcat-webapplication`. Import a Java Web Application ARchive (WAR) file inside an [Apache Tomcat](http://tomcat.apache.org) servlet container.
* `wrapper`. Wraps the `bin/wrapper` activation script inside the component into a [systemd](http://www.freedesktop.org/wiki/Software/systemd) job and activates or deactivates it.

Usage
=====
In order to use Dysnomia to deploy mutable components, we require two dependencies:

* A component containing a logical snapshot of the initial state of a mutable component
* A configuration file capturing properties of the container in which the component must be deployed

Providing a logical state snapshot of the component
---------------------------------------------------
The following file could be stored in `~/test-database/mysql-database/createdb.sql`
representing the logical state of a MySQL database. In this particular case, this
file is a collection of SQL statements setting up the initial schema of the
database:

    create table author
    ( AUTHOR_ID INTEGER NOT NULL,
      FirstName VARCHAR(255) NOT NULL,
      LastName  VARCHAR(255) NOT NULL,
      PRIMARY KEY(SELLER_ID)
    );
    
    create table books
    ( ISBN VARCHAR(255) NOT NULL,
      Title VARCHAR(255) NOT NULL,
      AUTHOR_ID VARCHAR(255) NOT NULL,
      PRIMARY KEY(ISBN),
      FOREIGN KEY(AUTHOR_ID) references author(AUTHOR_ID) on update cascade on delete cascade
    );

The folder `~/test-database` folder represents a logical state dump that we can
deploy through a Dysnomia module.

Providing the container configuration
-------------------------------------
Besides specifying the state of the database, we also need to know to which DBMS
instance (a.k.a. container) we have to deploy it. The container settings are
captured in a separate container configuration file, such as
`~/mysql-production`:

    type=mysql-database
    mysqlUsername=root
    mysqlPassword=verysecret

The above file is a very simple textual configuration files consisting of
key=value pairs. The `type` property is the only setting that is mandatory,
because it is used to invoke the corresponding Dysnomia module that takes care
of the deployment operation for that container. The remaining properties are
used by the particular Dysnomia module.

Executing a deployment activity
-------------------------------
With those two files, we can perform a deployment activity, such as activating a
MySQL database inside a MySQL DBMS instance:

    $ dysnomia --operation activate --component ~/test-database --container ~/mysql-production

Every component has its own way of representing its logical state and each of
them require different container settings. For databases, these are typically SQL
dumps and authentication settings.

Web applications have archive files (WAR/AAR) or a collection of web related
files (HTML, CSS etc.) as a representation of their logical state. Consult the
actual Dysnomia modules for more information.

Implementing custom Dysnomia modules
====================================
Custom Dysnomia modules are relatively easy to implement. Every Dysnomia module
is a process in which the first parameter represents the activity to execute and
the second parameter represents the path to a component containing a logical
state snapshot. The container properties are made available through environment
variables.

The following code fragment shows the source code of the `echo` module, that
simply echoes what it's doing:

    #!/bin/bash -e

    # Activation script that simply echos the service thats being activated or deactivated

    case "$1" in
        activate)
            echo "Echo activation script: Activate service: $2"
            ;;
        deactivate)
            echo "Echo activation script: Deactivate service: $2"
            ;;
        lock)
            echo "Echo activation script: Lock service: $2"
            ;;
        unlock)
            echo "Echo activation script: Unlock service: $2"
            ;;
    esac

    # Print the environment variables
    echo "Environment variables:"
    set

Currently, Dysnomia supports four activities:

* `activate` is used to activate the component in a container
* `deactivate` is used to deactivate the component in a container
* `lock` is invoked by Disnix before the upgrade transition starts. This operation can be used to consult a deployed component to determine whether it is safe to upgrade and to take precautions before the upgrade starts (such as queing incoming connections).
* `unlock` is invoked by Disnix after the upgrade transition is over. This can be used to notify the component to resume its normal operations.

The above code example is written in Bash, but any lanugage can be used as long
as the tool provides the same command-line interface and properly uses the
environment variables from the container specification.

License
=======
This package is released under the MIT license.
