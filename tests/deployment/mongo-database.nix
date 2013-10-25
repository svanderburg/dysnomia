{stdenv}:

stdenv.mkDerivation {
  name = "testdb";
  src = ../services/mongo-database;
  buildCommand =
  ''
    ensureDir $out/mongo-databases
    cp $src/*.js $out/mongo-databases
  '';
}
