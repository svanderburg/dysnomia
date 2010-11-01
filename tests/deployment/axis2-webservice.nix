{stdenv, jdk}:

stdenv.mkDerivation {
  name = "axis2-webservice";
  src = ../services/axis2-webservice;
  buildInputs = [ jdk ];
  buildPhase =
  ''
    javac Test.java
  '';
  installPhase =
  ''
    jar cfv test.aar Test.class META-INF/services.xml
    ensureDir $out/webapps/axis2/WEB-INF/services
    cp *.aar $out/webapps/axis2/WEB-INF/services
  '';
}
