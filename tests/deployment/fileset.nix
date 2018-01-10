{stdenv}:

stdenv.mkDerivation {
  name = "fileset";
  buildCommand = ''
    mkdir -p $out/bin
    cat > $out/bin/showfiles <<EOF
    #! ${stdenv.shell} -e
    ls /srv/fileset
    EOF
    chmod +x $out/bin/showfiles

    echo "/srv/fileset" > $out/.dysnomia-targetdir

    cat > $out/.dysnomia-fileset <<EOF
    symlink $out/bin
    mkdir files
    EOF
  '';
}
