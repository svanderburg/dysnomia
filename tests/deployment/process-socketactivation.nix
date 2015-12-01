{stdenv}:

stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*
    
    mkdir -p $out/etc
    cat > $out/etc/socket <<EOF
    [Unit]
    Description=Dummy socket for testing purposes
    
    [Socket]
    ListenStream=5123
    EOF
  '';
}
