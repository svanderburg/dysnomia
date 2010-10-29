{stdenv}:

stdenv.mkDerivation {
  name = "apache-webapplication";
  src = ../services/apache-webapplication;
  buildCommand = ''
    ensureDir $out/webapps/test
    cp $src/* $out/webapps/test
  '';
}
