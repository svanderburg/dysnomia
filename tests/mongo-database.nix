{ nixpkgs, tarball, buildFun }:

let
  dysnomia = buildFun {
    pkgs = import nixpkgs {};
    inherit tarball;
    enableMongoDatabase = true;
  };
in
with import nixpkgs {};
with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  # Test services

  mongo_database = import ./deployment/mongo-database.nix {
    inherit stdenv;
  };
in
makeTest {
  name = "mongo-database";

  nodes = {
    machine = {config, pkgs, ...}:

    {
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 4096;

      services.mongodb.enable = true;

      environment.systemPackages = [ dysnomia ];
    };
  };

  testScript =
    ''
      def check_num_of_snapshot_generations(num):
          actual_num = machine.succeed(
              "ls /var/state/dysnomia/snapshots/mongo-database/* | wc -l"
          )

          if int(num) != int(actual_num):
              raise Exception(
                  "Expecting {num} snapshot generations, but we have: {actual_num}".format(
                      num=num, actual_num=actual_num
                  )
              )


      start_all()

      # Test MongoDB module. Deploys a MongoDB instance,
      # inserts some data and verifies whether it can be accessed.
      # This test should succeed.

      machine.wait_for_unit("mongodb")

      machine.succeed(
          "dysnomia --type mongo-database --operation activate --component ${mongo_database} --environment"
      )
      machine.succeed(
          "[ \"$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" != \"\" ]"
      )

      # Activate the Mongo database again and should not cause duplicate records. This test should succeed.
      machine.succeed(
          "dysnomia --type mongo-database --operation activate --component ${mongo_database} --environment"
      )
      machine.succeed(
          "[ \"$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world' | wc -l)\" = \"1\" ]"
      )

      # Take a snapshot of the Mongo database.
      # This test should succeed.
      machine.succeed(
          "dysnomia --type mongo-database --operation snapshot --component ${mongo_database} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Take another snapshot of the Mongo database. Because nothing changed, no
      # new snapshot is supposed to be taken. This test should succeed.
      machine.succeed(
          "dysnomia --type mongo-database --operation snapshot --component ${mongo_database} --environment"
      )
      check_num_of_snapshot_generations(1)

      # Make a modification and take another snapshot. Because something
      # changed, a new snapshot is supposed to be taken. This test should
      # succeed.
      machine.succeed(
          "(echo 'use testdb;'; echo 'db.messages.save({ \"test\": \"test123\" });') | mongo"
      )
      machine.succeed(
          "dysnomia --type mongo-database --operation snapshot --component ${mongo_database} --environment"
      )
      check_num_of_snapshot_generations(2)

      # Run the garbage collect operation. Since the database is not considered
      # garbage yet, it should not be removed.
      machine.succeed(
          "dysnomia --type mongo-database --operation collect-garbage --component ${mongo_database} --environment"
      )
      machine.succeed(
          "[ \"$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" != \"\" ]"
      )

      # Deactivate the mongo database. This test should succeed.
      machine.succeed(
          "dysnomia --type mongo-database --operation deactivate --component ${mongo_database} --environment"
      )

      # Deactivate again. This test should succeed as the operation is idempotent.
      machine.succeed(
          "dysnomia --type mongo-database --operation deactivate --component ${mongo_database} --environment"
      )

      # Run the garbage collect operation. Since the database has been
      # deactivated it is considered garbage, so it should be removed.
      machine.succeed(
          "dysnomia --type mongo-database --operation collect-garbage --component ${mongo_database} --environment"
      )
      machine.fail(
          "[ \"$((echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo | grep 'Hello world')\" != \"\" ]"
      )

      # Activate the mongo database again. This test should succeed.
      machine.succeed(
          "dysnomia --type mongo-database --operation activate --component ${mongo_database} --environment"
      )

      # Restore the last snapshot and check whether it contains the recently
      # added record. This test should succeed.
      machine.succeed(
          "dysnomia --type mongo-database --operation restore --component ${mongo_database} --environment"
      )
      result = machine.succeed(
          "(echo 'show dbs;'; echo 'use testdb;'; echo 'db.messages.find();') | mongo"
      )

      if "test123" in result:
          print("mongo query returns: test123!")
      else:
          raise Exception("mongo collection should contain: test123!")
    '';
}
