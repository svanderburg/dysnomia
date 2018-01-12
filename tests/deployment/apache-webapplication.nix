{stdenv, enableState ? false}:

stdenv.mkDerivation {
  name = "apache-webapplication";
  src = ../services/apache-webapplication;
  buildCommand = ''
    mkdir -p $out/webapps/test
    cp $src/* $out/webapps/test
  '' + stdenv.lib.optionalString enableState ''
    find $out/webapps/test -type f | while read i
    do
        ( echo "symlink $i"
          echo "target test"
        ) >> $out/.dysnomia-fileset
    done
  '';
}
