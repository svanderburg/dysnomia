{ pkgs, tarball, buildFun, stdenv, jdk, makeTest }:

makeTest {
  name = "containers";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      imports = [ ../dysnomia-module.nix ];

      dysnomiaTest = {
        enable = true;
        enableAuthentication = true;

        properties = {
          mem = "$(grep 'MemTotal:' /proc/meminfo | sed -e 's/kB//' -e 's/MemTotal://' -e 's/ //g')";
        };

        components = {
          mysql-database = {
            testdb = import ./deployment/mysql-database.nix {
              inherit (pkgs) stdenv;
            };
          };

          postgresql-database = {
            testdb = import ./deployment/postgresql-database.nix {
              inherit (pkgs) stdenv;
            };
          };
        };
      };

      services = {
        mysql = {
          enable = true;
          package = pkgs.mariadb;
        };

        postgresql = {
          enable = true;
          package = pkgs.postgresql;
        };
      };

      environment.systemPackages = [ pkgs.graphviz ];
    };
  };

  testScript =
    ''
      start_all()

      machine.wait_for_unit("mysql")
      machine.wait_for_unit("postgresql")

      # Query the available containers. It should return a MySQL and a
      # PostgreSQL entry.

      result = machine.succeed("dysnomia-containers --query-containers")
      containers = result.split("\n")

      if "mysql-database" in containers:
          print("mysql-database is in the containers query!")
      else:
          raise Exception("mysql-database should be in the containers query!")

      if "postgresql-database" in containers:
          print("postgresql-database is in the containers query!")
      else:
          raise Exception("postgresql-database should be in the containers query!")

      # Query the available components. It should return a MySQL and a
      # PostgreSQL database.

      result = machine.succeed("dysnomia-containers --query-available-components")
      components = result.split("\n")

      if "mysql-database/testdb" in components:
          print("mysql-database/testdb is in the available components query!")
      else:
          raise Exception(
              "mysql-database/testdb should be in the available components query!"
          )

      if "postgresql-database/testdb" in components:
          print("postgresql-database/testdb is in the available components query!")
      else:
          raise Exception(
              "postgresql-database/testdb should be in the available components query!"
          )

      # Query the activated components. It should return nothing, as we have not
      # activated anything yet.

      result = machine.succeed("dysnomia-containers --query-activated-components")
      components = result.split("\n")

      if "mysql-database/testdb" not in components:
          print("We have no activated components!")
      else:
          raise Exception("We should have no activated components!")

      if "postgresql-database/testdb" not in components:
          print("We have no activated components!")
      else:
          raise Exception("We should have no activated components!")

      # Deploy the available components.
      machine.succeed("dysnomia-containers --deploy")

      # Query the activated components. It should return the MySQL and
      # PostgreSQL database.

      result = machine.succeed("dysnomia-containers --query-activated-components")
      containers = result.split("\n")

      if "mysql-database/testdb" in containers:
          print("mysql-database/testdb is in the activated components query!")
      else:
          raise Exception(
              "mysql-database/testdb should be in the activated components query!"
          )

      if "postgresql-database/testdb" in containers:
          print("postgresql-database/testdb is in the activated components query!")
      else:
          raise Exception(
              "postgresql-database/testdb should be in the activated components query!"
          )

      # Check whether the MySQL database has been created.
      result = machine.succeed("echo 'select * from test' | mysql -N testdb")

      if "Hello world" in result:
          print("MySQL query returns: Hello world!")
      else:
          raise Exception(
              "MySQL table should contain: Hello world, instead we have: $result!"
          )

      # Check whether the PostgreSQL database has been created.
      result = machine.succeed(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      if "Hello world" in result:
          print("PostgreSQL query returns: Hello world!")
      else:
          raise Exception("PostgreSQL table should contain: Hello world!")

      # Snapshot the state of all deployed mutable components and check if they
      # have actually been taken.
      machine.succeed("dysnomia-containers --snapshot")

      result = machine.succeed("dysnomia-snapshots --query-all")
      snapshots = result.split("\n")

      if any("mysql-database/testdb" in s for s in snapshots):
          print("mysql-database/testdb is in the snapshots query!")
      else:
          raise Exception("mysql-database/testdb is not in the snapshots query!")

      if any("postgresql-database/testdb" in s for s in snapshots):
          print("postgresql-database/testdb is in the snapshots query!")
      else:
          raise Exception("postgresql-database/testdb is not in the snapshots query!")

      # Modify the state of the databases

      machine.succeed("echo \"insert into test values ('Bye world');\" | mysql -N testdb")
      machine.succeed(
          "echo \"insert into test values ('Bye world');\" | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      # Restore the state of the databases and check whether the modifications
      # are gone.

      machine.succeed("dysnomia-containers --restore -y")

      result = machine.succeed("echo 'select * from test' | mysql -N testdb")

      if "Bye world" in result:
          raise Exception("MySQL table should not contain: Bye world!")
      else:
          print("MySQL does not contain: Bye world!")

      result = machine.succeed(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      if "Bye world" in result:
          raise Exception("PostgreSQL table should not contain: Bye world!")
      else:
          print("PostgreSQL does not contain: Bye world!")

      # Properties test. Check if the hostname property is there, whether the mem
      # property remains a shell substitution, and whether the supportedTypes
      # property is an array.

      machine.succeed('grep "^hostname=\\"machine\\"\$" /etc/dysnomia/properties')
      machine.succeed('grep "MemTotal" /etc/dysnomia/properties')
      machine.succeed('grep "supportedTypes=(" /etc/dysnomia/properties')

      # Visualize the current containers configuration. The output is produced
      # as a Hydra report.

      machine.succeed("dysnomia-containers --generate-dot > visualize.dot")
      machine.succeed("dot -Tpng visualize.dot > /tmp/xchg/visualize.png")
  '';
}
