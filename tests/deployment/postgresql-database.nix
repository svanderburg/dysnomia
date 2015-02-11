{stdenv}:

stdenv.mkDerivation {
  name = "testdb";
  src = ../services/mysql-database;
  buildCommand =
  ''
    mkdir -p $out/postgresql-databases
    cp $src/*.sql $out/postgresql-databases
  '';
}
