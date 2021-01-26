{stdenv, writeTextFile, coreutils, execline}:

let
  envfile = writeTextFile {
    name = "envfile";
    text = ''
      PATH=${coreutils}/bin
    '';
  };
in
stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*

    mkdir -p $out/etc/s6/sv/process
    cd $out/etc/s6/sv/process

    cat > run <<EOF
    #!${execline}/bin/execlineb -P
    envfile ${envfile}
    exec $out/bin/loop
    EOF

    echo "longrun" > type
  '';
}
