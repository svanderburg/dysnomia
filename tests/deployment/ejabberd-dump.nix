{stdenv}:

stdenv.mkDerivation {
  name = "ejabberd-dump";
  src = ../services/ejabberd-dump;
  buildCommand = ''
    ensureDir $out/ejabberd-dump
    cp $src/* $out/ejabberd-dump
  '';
}
