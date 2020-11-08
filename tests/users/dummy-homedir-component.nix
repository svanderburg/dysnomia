{stdenv}:

stdenv.mkDerivation {
  name = "dummy-homedir-component";
  buildCommand = ''
    mkdir -p $out/dysnomia-support/users
    cat > $out/dysnomia-support/users/unprivileged <<EOF
    homeDir=/home/unprivileged
    createHomeDir=1
    createHomeDirOnly=1
    EOF
  '';
}
