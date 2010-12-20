{stdenv}:

stdenv.mkDerivation {
  name = "testdb";
  src = ../services/mysql-database;
  buildCommand =
  ''
    ensureDir $out/postgresql-databases
    cp $src/*.sql $out/postgresql-databases
  '';
}
