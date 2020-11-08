{stdenv}:

stdenv.mkDerivation {
  name = "dummy-user-component";
  buildCommand = ''
    mkdir -p $out/dysnomia-support/groups
    cat > $out/dysnomia-support/groups/unprivileged <<EOF
    EOF

    mkdir -p $out/dysnomia-support/users
    cat > $out/dysnomia-support/users/unprivileged <<EOF
    group=unprivileged
    description=Unprivileged
    homeDir=/home/unprivileged
    createHomeDir=1
    shell=/bin/sh
    EOF
  '';
}
