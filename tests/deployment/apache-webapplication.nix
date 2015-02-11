{stdenv}:

stdenv.mkDerivation {
  name = "apache-webapplication";
  src = ../services/apache-webapplication;
  buildCommand = ''
    mkdir -p $out/webapps/test
    cp $src/* $out/webapps/test
  '';
}
