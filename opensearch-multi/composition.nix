{ pkgs, ... }:
let
  keystore-password = "usAe#%EX92R7UHSYwJ";
  truststore-password = "*!YWptTiu3&okU%E9a";
  opensearch-fixed = pkgs.opensearch.overrideAttrs
    (final: previous: {
      installPhase = previous.installPhase + ''
        chmod +x $out/plugins/opensearch-security/tools/*.sh
      '';
    });
  cluster-name = "boris";
  base-config = {
    enable = true;
    package = opensearch-fixed;

    extraJavaOptions = [
      "-Xmx512m" # Limite maximale de la mémoire utilisée par la machine virtuelle Java à 512 Mo
      "-Xms512m" # Mémoire initiale allouée par la machine virtuelle Java à 512 Mo
    ];

    settings = {
      "cluster.name" = cluster-name;
      "network.bind_host" = "0.0.0.0";
      "plugins.security.disabled" = true; # TODO: for the moment we disable the security plugin
      "cluster.initial_cluster_manager_nodes": [ "cluster_manager" ];
    };
  };
in
{
  # Useful link :
  # https://opensearch.org/docs/latest/tuning-your-cluster/
  # https://opensearch.org/docs/latest/install-and-configure/configuring-opensearch/cluster-settings/
  # https://opensearch.org/docs/latest/install-and-configure/configuring-opensearch/index/#dynamic-settings


  # From : https://opensearch.org/docs/latest/security/multi-tenancy/multi-tenancy-config/
  # The opensearch_dashboards.yml file includes additional settings:

  # opensearch.username: kibanaserver
  # opensearch.password: kibanaserver
  # opensearch.requestHeadersAllowlist: ["securitytenant","Authorization"]
  # opensearch_security.multitenancy.enabled: true
  # opensearch_security.multitenancy.tenants.enable_global: true
  # opensearch_security.multitenancy.tenants.enable_private: true
  # opensearch_security.multitenancy.tenants.preferred: ["Private", "Global"]
  # opensearch_security.multitenancy.enable_filter: false

  # Multi-tenancy is enabled in OpenSearch Dashboards by default. If you need to disable or change settings related to multi-tenancy, see the kibana settings in config/opensearch-security/config.yml, as shown in the following example:

  # config:
  #   dynamic:
  #     kibana:
  #       multitenancy_enabled: true
  #       private_tenant_enabled: true
  #       default_tenant: global tenant
  #       server_username: kibanaserver
  #       index: '.kibana'
  #     do_not_fail_on_forbidden: false


  #  IP remplacée par le nom du rôle
  roles = {
    vector = { pkgs, ... }: {
      environment.systemPackages = [ vector ];
      environment.noXlibs = false;

      services.vector = {
        enable = true;
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
              endpoints = [ "https://master:9200" ];
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

      environment.variables = {
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

    clusterManager = { pkgs, config, lib, ... }: {
      imports = [ ../opensearch-dashboards.nix ];

      environment.noXlibs = false;
      environment.systemPackages = with pkgs; [ opensearch-fixed jq ];

      # On ne connait pas les IP des nœuds à l'avance donc on
      # génère ça dynamiquement
      # TODO: vérifier que ça marche bien parce que
      # - peut-être que le fichier existe pas au moment du boot et est copié depuis le store ensuite
      # - peut-être qu'il existe mais qu'on a pas les droits pour le modifier
      environment.activationScripts.seed-hosts = ''
        CONF=/var/lib/opensearch/opensearch.yml
        echo "discovery.seed_hosts:" >> $CONF
        cat /etc/hosts | grep -E 'ingest|data' | cut -f 1 | awk '{ print "- \"" $0 "\"" }' >> $CONF
      '';

      services.opensearch = base-config // {
        settings."node.name" = "clusterManager";
        settings."node.roles": [ "cluster_manager" ];
      };

      services.opensearch-dashboards.enable = true;
    };

    # The ingest node is responsible for pre-processing documents before they are indexed
    ingest = { pkgs, config, lib, ... }: {
      environment.noXlibs = false;
      environment.systemPackages = with pkgs; [ opensearch-fixed ]; 

      services.opensearch = base-config {
        settings."node.name" = "ingest";
        settings."node.roles" = [ "ingest" ];
        settings."ingest.default_pipeline" = "my_pipeline";
      };
      # ...
    };

    # The data node stores the data and executes data-related operations such as search and aggregation
    data = { pkgs, config, lib, ... }: {
      environment.noXlibs = false;
      environment.systemPackages = with pkgs; [ opensearch-fixed ];

      services.opensearch = base-config // {
        settings."node.name" = "data";
        settings."node.roles" = [ "data" ];
      };
    };
  };

  dockerPorts.clusterManager = [ "5601:5601" "9200:9200" ];

  testScript = ''
    opensearch.start()
    opensearch.wait_for_unit("opensearch.service")
    opensearch.wait_for_open_port(9200)

    opensearch.succeed(
      "curl --fail localhost:9200"
    )

    opensearch.wait_for_unit("vector.service")

    # The inner curl command uses the Opensearch API and JQ to get the name of the Vector index
    # (this index contains the current date and thus has a different name every day).
    # The outer curl call just queries the content of the index and checks that it is in the expected
    # format with JQ
    opensearch.succeed(
      "curl --fail http://localhost:9200/$(curl --fail http://localhost:9200/_stats | jq -r '.indices | keys[]' | grep vector | tail -n 1)/_search | jq '.hits.hits[0]._source'"
    )
  '';
}
