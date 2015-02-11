{stdenv}:

stdenv.mkDerivation {
  name = "testdb";
  src = ../services/mysql-database;
  buildCommand =
  ''
    mkdir -p $out/mysql-databases
    cp $src/*.sql $out/mysql-databases
  '';
}
