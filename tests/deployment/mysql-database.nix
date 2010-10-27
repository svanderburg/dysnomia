{stdenv}:

stdenv.mkDerivation {
  name = "testdb";
  src = ../services/mysql-database;
  buildCommand =
  ''
    ensureDir $out/mysql-databases
    cp $src/*.sql $out/mysql-databases
  '';
}
