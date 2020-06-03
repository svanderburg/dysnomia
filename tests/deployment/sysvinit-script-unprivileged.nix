{stdenv, daemon, coreutils}:

stdenv.mkDerivation {
  name = "process";
  src = ../services/process;
  installPhase = ''
    mkdir -p $out/bin
    cp $src/* $out/bin
    chmod +x $out/bin/*

    # Create init script

    mkdir -p $out/etc/rc.d/init.d
    cat > $out/etc/rc.d/init.d/process <<EOF
    #! ${stdenv.shell} -e

    pidFile=/var/run/loop.pid

    case "\$1" in
       start)
           ${daemon}/bin/daemon --pidfile \$pidFile --unsafe -- su unprivileged -c $out/bin/loop
           ;;
       stop)
           if [ -e "\$pidFile" ]
           then
               ${coreutils}/bin/kill "\$(cat \$pidFile)"
           fi
           ;;
    esac
    EOF

    chmod +x $out/etc/rc.d/init.d/process

    # Create start/stop symlinks for each runlevel

    mkdir -p $out/etc/rc.d/rc{0,1,2,3,4,5,6}.d

    ln -s ../init.d/process $out/etc/rc.d/rc0.d/K00process
    ln -s ../init.d/process $out/etc/rc.d/rc1.d/K00process
    ln -s ../init.d/process $out/etc/rc.d/rc2.d/K00process
    ln -s ../init.d/process $out/etc/rc.d/rc3.d/S00process
    ln -s ../init.d/process $out/etc/rc.d/rc4.d/S00process
    ln -s ../init.d/process $out/etc/rc.d/rc5.d/S00process
    ln -s ../init.d/process $out/etc/rc.d/rc6.d/K00process

    mkdir -p $out/dysnomia-support/groups
    cat > $out/dysnomia-support/groups/unprivileged <<EOF
    EOF

    mkdir -p $out/dysnomia-support/users
    cat > $out/dysnomia-support/users/unprivileged <<EOF
    group=unprivileged
    description=Unprivileged
    shell=/bin/sh
    EOF
  '';
}
