{stdenv, inetutils}:

stdenv.mkDerivation {
  name = "tftp";
  buildCommand = ''
    mkdir -p $out/etc/xinetd.d
    cat > $out/etc/xinetd.d/tftp <<EOF
    service tftp
    {
        socket_type = dgram
        protocol = udp
        bind = 127.0.0.1
        wait = yes
        server = ${inetutils}/libexec/tftpd
        disable = no
        user = root
    }
    EOF
  '';
}
