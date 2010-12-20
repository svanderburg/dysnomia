{stdenv}:

stdenv.mkDerivation {
  name = "testrepos";
  src = ../services/subversion-repository;
  buildCommand =
  ''
    ensureDir $out/subversion-repositories
    cp $src/*.dump $out/subversion-repositories
  '';
}
