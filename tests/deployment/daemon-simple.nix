{stdenv, daemon}:

let
  processPkg = stdenv.mkDerivation {
    name = "loop";
    src = ../services/process;
    installPhase = ''
      mkdir -p $out/bin
      cp $src/* $out/bin
      chmod +x $out/bin/*
    '';
  };
in
stdenv.mkDerivation {
  name = "daemon-simple";
  buildCommand = ''
    mkdir -p $out/bin
    cat > $out/bin/loop <<EOF
    #! ${stdenv.shell} -e
    exec ${daemon}/bin/daemon --pidfile /var/run/loop.pid --unsafe -- ${processPkg}/bin/loop
    EOF
    chmod +x $out/bin/loop
  '';
}
