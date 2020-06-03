{stdenv, coreutils}:

stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*

    mkdir -p $out/etc/systemd/system
    cat > $out/etc/systemd/system/process-unprivileged.service <<EOF
    [Unit]
    Description=Simple looping process

    [Service]
    Environment=PATH=${coreutils}/bin
    ExecStart=$out/bin/loop
    User=unprivileged
    Group=unprivileged
    EOF

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
