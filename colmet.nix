{ lib, pkgs, config,  ... }:

let
  cfg-collector = config.services.colmet-collector;
  cfg-node = config.services.colmet-node;
  auth-file = pkgs.writeText "colmet-opensearch-auth" "admin:admin";
in
with lib;
{
  config.environment.systemPackages = with pkgs; [ nur.repos.kapack.colmet ];

  # option to enable the colmet collector
  options.services.colmet-collector = {
    enable = mkEnableOption (mdDoc "Enable the Colmet collector service");
  };

  # option to enable colmet nodes
  options.services.colmet-node = {
    enable = mkEnableOption (mdDoc "Enable the Colmet node service");
  };

  # if colmet-collector is enable
  config.systemd.services.colmet-collector = mkIf cfg-collector.enable {
    description = "Colmet collector";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" (mkIf config.services.opensearch.enable "opensearch.service") ];
    serviceConfig = {
      ExecStart = "${pkgs.nur.repos.kapack.colmet}/bin/colmet-collector -vvv " +
        "--zeromq-bind-uri tcp://0.0.0.0:5556 " +
        "--buffer-size 5000 " +
        "--sample-period 3 " +
        "--elastic-host https://127.0.0.1:9200 " +
        "--elastic-index-prefix colmet_dahu_ " +
        "--http-credentials ${auth-file} " +
        "--no-check-certificates";
    };
  };

  # if colmet-node is enable
  config.systemd.services.colmet-node = mkIf cfg-node.enable {
    description = "Colmet node";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" (mkIf config.services.opensearch.enable "opensearch.service") ];
    serviceConfig = {
      ExecStart = "${pkgs.nur.repos.kapack.colmet}/bin/colmet-node -vvv --zeromq-uri tcp://127.0.0.1:5556";
    };
  };
}
