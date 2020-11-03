{stdenv}:

stdenv.mkDerivation {
  name = "process-unprivileged";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*

    mkdir -p $out/etc
    cat > $out/etc/process_config <<EOF
    container_username=unprivileged
    container_group=unprivileged
    container_uid=20000
    container_gid=20000
    EOF
  '';
}
