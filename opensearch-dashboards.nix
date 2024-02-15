{ pkgs, lib, config, ... }:
let
  osd =
    pkgs.stdenvNoCC.mkDerivation rec {
      pname = "opensearch-dashboards";
      version = "2.11.1";
      src = pkgs.fetchurl {
        url = "https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/${version}/opensearch-dashboards-${version}-linux-x64.tar.gz";
        hash = "sha256-ftGHFz+qRhBcbne95UaLV+Hz/5+gMC9kwtoal87HnXo=";
      };

      nativeBuildInputs = [ pkgs.makeWrapper ];

      phases = [ "unpackPhase" "installPhase" "fixupPhase" "postInstall" ];

      installPhase = ''
        mkdir $out
        cp package.json $out
        cp -r bin $out
        cp -r config $out
        cp -r node_modules $out
        cp -r plugins $out
        cp -r src $out
      '';

      postInstall = ''
        	chmod +x $out/bin/*
          wrapProgram $out/bin/opensearch-dashboards --set OSD_NODE_HOME ${pkgs.nodejs}
      '';

      meta = {
        description = "Dashboards for OpenSearch";
        homepage = "https://github.com/opensearch-project/OpenSearch";
        license = lib.licenses.asl20;
        platforms = lib.platforms.unix;
      };
    };
  cfg = config.services.opensearch-dashboards;
in
with lib;
{
  options.services.opensearch-dashboards = {
    enable = mkEnableOption (mdDoc "Opensearch Dashboards");
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ osd ];
    systemd.services.opensearch-dashboards = {
      description = "Dashboards for OpenSearch";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" (mkIf config.services.opensearch.enable "opensearch.service") ];
      requires = [ "network-online.target" ];
      serviceConfig =
        let
          yaml = pkgs.formats.yaml { };
          json = pkgs.formats.json { };
          conf = yaml.generate "opensearch-dashboard-config.yml" {
            # This is a translation of the default config
            # TODO: make it possible to add / override options with
            # the NixOS module 
            opensearch = {
              hosts = [ "http://localhost:9200" ];
              ssl.verificationMode = "none";
              username = "kibanaserver";
              password = "kibanaserver";
              requestHeadersWhitelist = [ "authorization" "securitytenant" ];
            };

            server.host = "0.0.0.0";
            server.ssl.enabled = false;

            opensearch_security = {
              multitenancy.enabled = true;
              multitenancy.tenants.preferred = [ "Private" "Global" ];
              readonly_mode.roles = [ "kibana_read_only" ];
              cookie.secure = false;
            };

            # plugins.security.restapi.roles_enabled = [ "all_access" ];
          };
          # reference : https://opensearch.org/docs/latest/security/configuration/yaml/#internal_usersyml
          opensearchAdmin = json.generate "opensearch-admin.json" {
            password = "admin";
            reserved = true;
            backend_roles = [ "admin" ];
          };
        in
        {
          ExecStart = "${osd}/bin/opensearch-dashboards --config ${conf}";
          User = "opensearch";
          Group = "opensearch";
          StateDirectory = "opensearch-dashboards";
          # ExecStartPre = mkIf config.services.opensearch.enable ''
          #   ${pkgs.curl}/bin/curl -vvv --fail -T ${opensearchAdmin} http://localhost:9200/_plugins/_security/api/internalusers/admin
          # '';
        };
    };
  };
}
