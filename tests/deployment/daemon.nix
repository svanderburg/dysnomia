{stdenv, daemon}:

stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin

    pidFile=/var/run/loop.pid

    cat > $out/bin/daemon <<EOF
    #! ${stdenv.shell} -e
    exec ${daemon}/bin/daemon --pidfile $pidFile --unsafe -- $out/bin/loop
    EOF

    chmod +x $out/bin/*

    mkdir -p $out/etc/dysnomia/process
    cat > $out/etc/dysnomia/process/loop <<EOF
    process=$out/bin/daemon
    pidFile=$pidFile
    EOF
  '';
}
