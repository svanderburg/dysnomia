{dockerTools, stdenv, buildEnv, nginx}:

let
  dockerImage = dockerTools.buildImage {
    name = "nginxexp";
    tag = "test";
    copyToRoot = buildEnv {
      name = "docker-packages";
      paths = [ nginx ];
    };

    runAsRoot = ''
      ${dockerTools.shadowSetup}
      groupadd -r nogroup
      useradd -r nobody -g nogroup -d /dev/null
      mkdir -p /tmp
      mkdir -p /var/log/nginx
      mkdir -p /var/cache/nginx
      mkdir -p /var/www
      cp ${./index.html} /var/www/index.html
    '';

    config = {
      Cmd = [ "${nginx}/bin/nginx" "-g" "daemon off;" "-c" ./nginx.conf ];
      Expose = {
        "80/tcp" = {};
      };
    };
  };
in
stdenv.mkDerivation {
  name = "nginxexp";
  buildCommand = ''
    mkdir -p $out
    cat > $out/nginxexp-docker-settings <<EOF
    dockerImage=${dockerImage}
    dockerImageTag=nginxexp:test
    EOF

    cat > $out/nginxexp-docker-createparams <<EOF
    -p
    80:80
    EOF
  '';
}
