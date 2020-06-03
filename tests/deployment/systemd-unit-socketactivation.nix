{stdenv, coreutils}:

stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*

    mkdir -p $out/etc/systemd/system
    cat > $out/etc/systemd/system/process.service <<EOF
    [Unit]
    Description=Simple looping process

    [Service]
    Environment=PATH=${coreutils}/bin
    ExecStart=$out/bin/loop
    EOF

    cat > $out/etc/systemd/system/process.socket <<EOF
    [Unit]
    Description=Dummy socket for testing purposes

    [Socket]
    ListenStream=5123
    EOF
  '';
}
