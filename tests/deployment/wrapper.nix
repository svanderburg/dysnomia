{stdenv}:

stdenv.mkDerivation {
  name = "wrapper";
  src = ../services/wrapper;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/wrapper $out/bin
    chmod +x $out/bin/*
  '';
}
