{stdenv, jdk}:

stdenv.mkDerivation {
  name = "tomcat-webapplication";
  src = ../services/tomcat-webapplication;
  buildInputs = [ jdk ];
  buildPhase =
  ''
    mkdir tomcat-webapplication
    cd tomcat-webapplication
    cp $src/* .
    jar cfv ../tomcat-webapplication.war *
    cd ..
  '';
  installPhase =
  ''
    mkdir -p $out/webapps
    cp *.war $out/webapps
  '';
}
