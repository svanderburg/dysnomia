{stdenv}:

stdenv.mkDerivation {
  name = "testrepos";
  src = ../services/subversion-repository;
  buildCommand =
  ''
    mkdir -p $out/subversion-repositories
    cp $src/*.dump $out/subversion-repositories
  '';
}
