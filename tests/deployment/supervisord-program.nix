{stdenv, coreutils}:

stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*

    mkdir -p $out/conf.d
    cat > $out/conf.d/loop.conf <<EOF
    [program:loop]
    command=$out/bin/loop
    environment=PATH=${coreutils}/bin
    EOF
  '';
}
