{ pkgs, lib, ... }:
let
  keystore-password = "usAe#%EX92R7UHSYwJ";
  truststore-password = "*!YWptTiu3&okU%E9a";
  opensearch-fixed = pkgs.opensearch.overrideAttrs (final: previous: {
    installPhase = previous.installPhase + ''
      chmod +x $out/plugins/opensearch-security/tools/*.sh
    '';
  });
  cluster-name = "boris";
  service-config = lib.recursiveUpdate {
    enable = true;
    package = opensearch-fixed;

    extraJavaOptions = [
      "-Xmx512m" # Limite maximale de la mémoire utilisée par la machine virtuelle Java à 512 Mo
      "-Xms512m" # Mémoire initiale allouée par la machine virtuelle Java à 512 Mo
    ];

    settings = {
      "node.name" = "localhost";
      "cluster.name" = cluster-name;
      "network.bind_host" = "0.0.0.0";
      "network.host" = "localhost";
      "plugins.security.disabled" = true; # TODO: for the moment we disable the security plugin
      "discovery.type" = "zen";
    };
  };
  opensearch-node = role: {
    imports = [ ../opensearch-dashboards.nix ];

    boot.kernel.sysctl."vm.max_map_count" = 262144;

    environment.noXlibs = false;
    environment.systemPackages = with pkgs; [ opensearch-fixed jq ];

    systemd.services.opensearch.serviceConfig.ExecStartPre = populate-hosts-script;
    services.opensearch = service-config {
      settings."node.roles" = [ role ];
    };
  };
  # On ne connait pas les IP des nœuds à l'avance donc on
  # génère ça dynamiquement
  populate-hosts-script = [
    "${
      pkgs.writeShellScriptBin "configure-opensearch" ''
        CONF=/var/lib/opensearch/config/opensearch.yml

        while [ ! -f $CONF ]; do
          sleep 1
        done

        chmod +w $CONF

        # Depending on the flavour, the /etc/nxc/deployment.json file
        # does not contain the same information
        # We build a temporary file that contains the hostnames of all deployed nodes
        # regardless of the current flavour
        # We first see if we are in a VM or on Grid5000
        declare -a JQ_PIPELINE
        if grep "ssh_key.pub" /etc/nxc/deployment.json; then
          JQ_PIPELINE=('"- " + (.deployment | map(.host) | .[])')
        else
          # Same as above, but in this case we are in Docker
          # and the deployment.json format is not exactly the same
          JQ_PIPELINE=('"- " + (.deployment | keys | .[])')
        fi

        # All nodes must have discovery.seed_hosts set to the IP of manager nodes
        echo "discovery.seed_hosts:" >> $CONF
        ${pkgs.jq}/bin/jq "''${JQ_PIPELINE[@]}" /etc/nxc/deployment.json -r | grep manager >> $CONF

        # On manager nodes, they should also be listed in cluster.initial_cluster_manager_nodes
        if hostname | grep manager; then
          echo "cluster.initial_cluster_manager_nodes:" >> $CONF
          ${pkgs.jq}/bin/jq "''${JQ_PIPELINE[@]}" /etc/nxc/deployment.json -r | grep manager >> $CONF
        fi

        # Replace localhost with the actual hostname
        sed -i "s/localhost/$(hostname)/" $CONF
      ''
    }/bin/configure-opensearch"
  ];
in {
  roles = {
    manager = { pkgs, config, lib, ... }: lib.recursiveUpdate (opensearch-node "cluster_manager") {
      services.opensearch-dashboards.enable = true;
    };

    # The ingest node is responsible for pre-processing documents before they are indexed
    ingest = { pkgs, config, lib, ... }: opensearch-node "ingest";

    # The data node stores the data and executes data-related operations such as search and aggregation
    data = { pkgs, config, lib, ... }: opensearch-node "data";

    vector = { lib, pkgs, config, ... }: {
      environment.systemPackages = [ pkgs.vector ];
      environment.noXlibs = false;

      services.vector = {
        enable = true;
        journaldAccess = true;
        settings = {
          sources = {
            "in" = { type = "stdin"; };
            "systemd" = { type = "journald"; };
          };
          sinks = {
            out = {
              inputs = [ "in" ];
              type = "console";
              encoding = { codec = "text"; };
            };
            opensearch = {
              inputs = [ "systemd" ];
              type = "elasticsearch";
              endpoints = [ "https://clusterManager:9200" ];
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
        VECTOR_CONFIG = lib.lists.last (builtins.split " "
          config.systemd.services.vector.serviceConfig.ExecStart);
      };
    };
  };

  dockerPorts.manager = [ "5601:5601" "9200:9200" ];

  testScript = ''
    for opensearch in [manager, data, ingest]:
      opensearch.start()
      opensearch.wait_for_unit("opensearch.service")
      opensearch.wait_for_open_port(9200)

      opensearch.succeed(
        "curl --fail localhost:9200"
      )

    vector.start()
    vector.wait_for_unit("vector.service")

    # The inner curl command uses the Opensearch API and JQ to get the name of the Vector index
    # (this index contains the current date and thus has a different name every day).
    # The outer curl call just queries the content of the index and checks that it is in the expected
    # format with JQ
    manager.succeed(
      "curl --fail http://localhost:9200/$(curl --fail http://localhost:9200/_stats | jq -r '.indices | keys[]' | grep vector | tail -n 1)/_search | jq '.hits.hits[0]._source'"
    )

    # This script gets the host name of all nodes in the cluster, and checks that all the expected nodes
    # are present
    manager.succeed(
      "curl -s http://localhost:9200/_nodes/ | jq '.nodes.[] | .host' -r | grep ingest"
    )
    manager.succeed(
      "curl -s http://localhost:9200/_nodes/ | jq '.nodes.[] | .host' -r | grep data"
    )
    manager.succeed(
      "curl -s http://localhost:9200/_nodes/ | jq '.nodes.[] | .host' -r | grep manager"
    )
  '';
}