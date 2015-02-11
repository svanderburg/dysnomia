{stdenv}:

stdenv.mkDerivation {
  name = "ejabberd-dump";
  src = ../services/ejabberd-dump;
  buildCommand = ''
    mkdir -p $out/ejabberd-dump
    cp $src/*.dump $out/ejabberd-dump
  '';
}
