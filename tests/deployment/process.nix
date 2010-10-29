{stdenv}:

stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    ensureDir $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*
  '';
}
