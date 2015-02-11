{stdenv}:

stdenv.mkDerivation {
  name = "wrapper-unprivileged";
  src = ../services/wrapper;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/wrapper $out/bin
    chmod +x $out/bin/*
    
    mkdir -p $out/etc
    cat > $out/etc/wrapper_config <<EOF
    container_username=unprivileged
    container_group=unprivileged
    container_uid=20000
    container_gid=20000
    EOF
  '';
}
