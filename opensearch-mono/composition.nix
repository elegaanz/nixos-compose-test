{ pkgs, enable-colmet ? true, enable-vector ? true, ... }:
let
  keystore-password = "usAe#%EX92R7UHSYwJ";
  truststore-password = "*!YWptTiu3&okU%E9a";
  opensearch-fixed = pkgs.opensearch.overrideAttrs
    (final: previous: {
      installPhase = previous.installPhase + ''
        chmod +x $out/plugins/opensearch-security/tools/*.sh
      '';
    });
in
{
  roles = {
    opensearch = { pkgs, config, lib, ... }:
      {
        imports = [ ../opensearch-dashboards.nix ../colmet.nix ];

        security.pki.certificateFiles = [ "${pkgs.opensearch-root-cert}/cert.pem" ];
        environment.noXlibs = false;
        environment.systemPackages = with pkgs; [ opensearch-fixed jq ] ++ (if enable-vector then [ vector ] else []);

        systemd.services.opensearch.serviceConfig.ExecStartPre = [
          pkgs.init-keystore
        ];
        systemd.services.opensearch.serviceConfig.ExecStartPost = lib.mkForce [
          pkgs.wait-and-run-security-admin
        ];

        services.opensearch = {
          enable = true;
          package = opensearch-fixed;
          settings."network.bind_host" = "0.0.0.0";
          settings."plugins.security.disabled" = false;
          settings."plugins.security.ssl.transport.keystore_type" = "PKCS12";
          settings."plugins.security.ssl.transport.keystore_password" = keystore-password;
          settings."plugins.security.ssl.transport.truststore_filepath" = "/var/lib/opensearch/config/ssl-truststore.p12";
          settings."plugins.security.ssl.transport.truststore_type" = "PKCS12";
          settings."plugins.security.ssl.transport.truststore_password" = truststore-password;
          settings."plugins.security.ssl.http.enabled" = true;
          settings."plugins.security.ssl.http.keystore_filepath" = "/var/lib/opensearch/config/ssl-keystore.p12";
          settings."plugins.security.ssl.http.keystore_type" = "PKCS12";
          settings."plugins.security.ssl.http.keystore_password" = keystore-password;
          settings."plugins.security.ssl.http.truststore_filepath" = "/var/lib/opensearch/config/ssl-truststore.p12";
          settings."plugins.security.ssl.http.truststore_type" = "PKCS12";
          settings."plugins.security.ssl.http.truststore_password" = truststore-password;
          settings."plugins.security.authcz.admin_dn" = [ "CN=admin_secu_le_boss" ];
          settings."plugins.security.ssl.transport.keystore_alias" = "opensearch";
          settings."plugins.security.ssl.transport.keystore_filepath" = "/var/lib/opensearch/config/ssl-keystore.p12";
          # Configuration des options Java supplémentaires (uniquement pour le service "opensearch")
          # Les machines virtuelles créées avec `nxc build -f vm` n'ont qu'un Mo de mémoire vive
          # Par défaut, la JVM demande plus de mémoire que ça et ne peut pas démarrer
          # Avec ces options, on limite son utilisation de la RAM
          extraJavaOptions = [
            "-Xmx512m" # Limite maximale de la mémoire utilisée par la machine virtuelle Java à 512 Mo
            "-Xms512m" # Mémoire initiale allouée par la machine virtuelle Java à 512 Mo
          ];
        };


        # Vector est système de gestion de logs
        services.vector = {
          enable = enable-vector;
          journaldAccess = true;
          settings = {
            sources = {
              "in" = {
                type = "stdin";
              };
              "systemd" = {
                type = "journald";
              };
            };
            sinks = {
              out = {
                inputs = [ "in" ];
                type = "console";
                encoding = {
                  codec = "text";
                };
              };
              opensearch = {
                inputs = [ "systemd" ];
                type = "elasticsearch";
                endpoints = ["https://127.0.0.1:9200"];
                auth = {
                  strategy = "basic";
                  user = "admin";
                  password = "admin";
                };
                tls.verify_certificate = false;
              };
            };
          };
        };
        services.opensearch-dashboards.enable = true;
        services.colmet-collector.enable = enable-colmet;
        services.colmet-node.enable = enable-colmet;

        environment.variables = lib.mkIf enable-vector {
          # La variable "VECTOR_CONFIG" défini le chemin de la configuration à utiliser quand on
          # lance la commande `vector`. Le service Systemd génère une config à partir de `services.vector.settings`
          # et s'assure que le service utilise bien ce fichier. Mais il faut aussi indiquer où ce trouve
          # ce fichier de configuration à l'outil en ligne de commande disponible dans le PATH.
          # On parse la configuration systemd pour récupérer le chemin du fichier.
          VECTOR_CONFIG = lib.lists.last (
            builtins.split " " config.systemd.services.vector.serviceConfig.ExecStart
          );
        };
      };
  };

  dockerPorts.opensearch = [ "5601:5601" "9200:9200" ];

  testScript = ''
    import time
    opensearch.start()
    opensearch.wait_for_unit("opensearch.service")
    opensearch.wait_for_open_port(9200)

    opensearch.succeed(
      "curl -k -u admin:admin --fail https://localhost:9200"
    )

    opensearch.wait_for_unit("opensearch-dashboards.service")
    opensearch.wait_for_open_port(5601)
    # When starting, opensearch-dashboards binds the port but need some time to start
    time.sleep(10)
    opensearch.succeed(
      "curl --fail http://localhost:5601/"
    )
  '' + (if enable-vector then ''

    opensearch.wait_for_unit("vector.service")

    # The inner curl command uses the Opensearch API and JQ to get the name of the Vector index
    # (this index contains the current date and thus has a different name every day).
    # The outer curl call just queries the content of the index and checks that it is in the expected
    # format with JQ
    opensearch.succeed(
      "curl -k -u admin:admin --fail https://localhost:9200/$(curl -k -u admin:admin --fail https://localhost:9200/_stats | jq -r '.indices | keys[]' | grep vector | tail -n 1)/_search | jq '.hits.hits[0]._source'"
    )
  '' else "") + (if enable-colmet then ''
    # Check that colmet runs…
    opensearch.wait_for_unit("colmet-node.service")
    opensearch.wait_for_unit("colmet-collector.service")
    # That the collector has set up a ZeroMQ server…
    opensearch.succeed("netstat -tlnp | grep :5556")
    # And that the index was created in OpenSearch
    opensearch.succeed("curl -ku admin:admin https://localhost:9200/_cat/indices | grep colmet")
  '' else "");
}
