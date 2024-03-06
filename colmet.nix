{ lib, pkgs, config,  ... }:

let
  colmet = pkgs.python3Packages.buildPythonApplication rec {
    name = "colmet-${version}";
    version = "0.6.10.dev0";

    src = pkgs.fetchFromGitHub {
      owner = "oar-team";
      repo = "colmet";
      rev = "a1c1c32e9f6014ddf8253842df27579b46b9a2fa";
      sha256 = "sha256-wXsJtvml6PdG1V5hE7wmpdEcAvof6U1NPc1rFR15NHU=";
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

    patches= [ ./colmet-hwm-constants.patch ];

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
  auth-file = pkgs.writeText "colmet-opensearch-auth" "admin:admin";
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
      ExecStart = "${colmet}/bin/colmet-collector -vvv " +
        "--zeromq-bind-uri tcp://0.0.0.0:5556 " +
        "--buffer-size 5000 " +
        "--sample-period 3 " +
        "--elastic-host https://127.0.0.1:9200 " +
        "--elastic-index-prefix colmet_dahu_ " +
        "--http-credentials ${auth-file} " +
        "--no-check-certificates";
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
