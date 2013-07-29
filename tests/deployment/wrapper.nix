{stdenv}:

stdenv.mkDerivation {
  name = "wrapper";
  src = ../services/wrapper;
  installPhase = ''
    ensureDir $out/bin
    cp $src/wrapper $out/bin
    chmod +x $out/bin/*
  '';
}
