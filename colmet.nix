{ lib, pkgs, config,  ... }:

let
  colmet = pkgs.python3Packages.buildPythonApplication rec {
    name = "colmet-${version}";
    version = "0.5.4";

    src = pkgs.fetchFromGitHub {
      owner = "oar-team";
      repo = "colmet";
      rev = "4cc29227fcaf5236d97dde74b9a52e04250a5b77";
      sha256 = "1g2m6crdmlgk8c57qa1nss20128dnw9x58yg4r5wdc7zliicahqq";
    };

    buildInputs = [ pkgs.powercap ];

    propagatedBuildInputs = with pkgs.python3Packages; [
      pyinotify
      pyzmq
      tables
      requests
    ];

    preBuild = ''
      mkdir -p $out/lib
      sed -i "s#/usr/lib/#$out/lib/#g" colmet/node/backends/perfhwstats.py
      sed -i "s#/usr/lib/#$out/lib/#g" colmet/node/backends/RAPLstats.py
      sed -i "s#/usr/lib/#$out/lib/#g" colmet/node/backends/lib_perf_hw/makefile
      sed -i "s#/usr/lib/#$out/lib/#g" colmet/node/backends/lib_rapl/makefile
    '';

    # Tests do not pass
    doCheck = false;

    patches= [./hardwarecorrupted.patch];

    meta = with lib; {
      description = "Collecting metrics about process running in cpuset and in a distributed environnement";
      homepage = https://github.com/oar-team/colmet;
      platforms = pkgs.powercap.meta.platforms;
      licence = licenses.gpl2;
      longDescription = ''
    '';
    };
  };
  cfg-collector = config.services.colmet-collector;
  cfg-node = config.services.colmet-node;
in
with lib;
{
  config.environment.systemPackages = [ colmet ];

  #option to enable the colmet collector
  options.services.colmet-collector = {
    enable = mkEnableOption (mdDoc "Enable the Colmet collector service");
  };

  #option to enable colmet nodes
  options.services.colmet-node = {
    enable = mkEnableOption (mdDoc "Enable the Colmet node service");
  };

  #if colmet-collector is enable
  config.systemd.services.colmet-collector = mkIf cfg-collector.enable {
    description = "Colmet collector";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" (mkIf config.services.opensearch.enable "opensearch.service") ];
    serviceConfig = {
      ExecStart = "${colmet}/bin/colmet-collector -vvv \
        --zeromq-bind-uri tcp://192.168.0.1:5556 \
        --buffer-size 5000 \
        --sample-period 3 \
        --elastic-host https://127.0.0.1:9200 \
        --elastic-index-prefix colmet_dahu_ 2>>/var/log/colmet_err.log >> /var/log/colmet.log \
        --no-check-certificates";
    };
  };

  #if colmet-node is enable
  config.systemd.services.colmet-node = mkIf cfg-node.enable {
    description = "Colmet node";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" (mkIf config.services.opensearch.enable "opensearch.service") ];
    serviceConfig = {
      ExecStart = "${colmet}/bin/colmet-node -vvv --zeromq-uri tcp://127.0.0.1:5556";
    };
  };
}
