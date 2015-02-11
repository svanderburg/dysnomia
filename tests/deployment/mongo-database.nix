{stdenv}:

stdenv.mkDerivation {
  name = "testdb";
  src = ../services/mongo-database;
  buildCommand =
  ''
    mkdir -p $out/mongo-databases
    cp $src/*.js $out/mongo-databases
  '';
}
