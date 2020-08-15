{stdenv, coreutils, hello}:

stdenv.mkDerivation {
  name = "hello-timer";
  buildCommand = ''
    mkdir -p $out/bin
    cat > $out/bin/hello <<EOF
    #! ${stdenv.shell} -e
    echo "Hello!"
    EOF
    chmod +x $out/bin/hello

    mkdir -p $out/etc/systemd/system
    cat > $out/etc/systemd/system/hello.service <<EOF
    [Unit]
    Description=Hello

    [Service]
    ExecStart=$out/bin/hello
    Type=oneshot
    EOF

    cat > $out/etc/systemd/system/hello.timer <<EOF
    [Unit]
    Description=Dummy timer for testing purposes
    Requires=hello.service

    [Timer]
    OnActiveSec=1s
    AccuracySec=1s
    EOF
  '';
}
