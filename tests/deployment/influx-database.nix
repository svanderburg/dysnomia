{stdenv}:

stdenv.mkDerivation {
  name = "testdb";
  src = ../services/influx-database;
  buildCommand =
  ''
    mkdir -p $out/influx-databases
    cp $src/*.influxql $out/influx-databases
  '';
}
