{stdenv}:

stdenv.mkDerivation {
  name = "wrapper";
  src = ../services/wrapper;
  installPhase = ''
    ensureDir $out/bin
    cp $src/loop $out/bin
    sed -e "s|@loop@|$out/bin/loop|" $src/wrapper.in > $out/bin/wrapper
    chmod +x $out/bin/*
  '';
}
