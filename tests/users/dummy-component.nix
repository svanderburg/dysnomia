{stdenv}:

stdenv.mkDerivation {
  name = "dummy-component";
  buildCommand = ''
    mkdir -p $out/dysnomia-support/groups
    cat > $out/dysnomia-support/groups/unprivileged <<EOF
    EOF

    mkdir -p $out/dysnomia-support/users
    cat > $out/dysnomia-support/users/unprivileged <<EOF
    group=unprivileged
    description=Unprivileged
    shell=/bin/sh
    EOF
  '';
}
