{stdenv, coreutils, hello}:

stdenv.mkDerivation {
  name = "hello";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*

    mkdir -p $out/etc/systemd/system
    cat > $out/etc/systemd/system/hello.service <<EOF
    [Unit]
    Description=Hello

    [Service]
    ExecStart=${hello}/bin/hello
    Type=oneshot
    EOF

    cat > $out/etc/systemd/system/hello.timer <<EOF
    [Unit]
    Description=Dummy timer for testing purposes
    Requires=hello.service

    [Timer]
    OnUnitActiveSec=1s
    AccuracySec=1s
    EOF
  '';
}
