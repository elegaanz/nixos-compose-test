{ lib, pkgs, ... }:
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
      "-Xmx512m" # Limit Java VM memory usage to 512 MB
      "-Xms512m" # Java VM initial memory allocation set to 512 MB
    ];

    settings = {
      "node.name" = "localhost";
      "cluster.name" = cluster-name;
      "network.bind_host" = "0.0.0.0";
      "network.host" = "localhost";
      "discovery.type" = "zen";

      # Security configuration
      "plugins.security.disabled" = false;
      "plugins.security.ssl.transport.keystore_type" = "PKCS12";
      "plugins.security.ssl.transport.keystore_password" = keystore-password;
      "plugins.security.ssl.transport.keystore_alias" = "opensearch";
      "plugins.security.ssl.transport.keystore_filepath" = "/var/lib/opensearch/config/ssl-keystore.p12";
      "plugins.security.ssl.transport.truststore_filepath" = "/var/lib/opensearch/config/ssl-truststore.p12";
      "plugins.security.ssl.transport.truststore_type" = "PKCS12";
      "plugins.security.ssl.transport.truststore_password" = truststore-password;
      
      "plugins.security.ssl.http.enabled" = true;
      "plugins.security.ssl.http.keystore_filepath" = "/var/lib/opensearch/config/ssl-keystore.p12";
      "plugins.security.ssl.http.keystore_type" = "PKCS12";
      "plugins.security.ssl.http.keystore_password" = keystore-password;
      "plugins.security.ssl.http.truststore_filepath" = "/var/lib/opensearch/config/ssl-truststore.p12";
      "plugins.security.ssl.http.truststore_type" = "PKCS12";
      "plugins.security.ssl.http.truststore_password" = truststore-password;
      
      "plugins.security.authcz.admin_dn" = [ "CN=admin_secu_le_boss" ];
      "plugins.security.nodes_dn" = [ "CN=manager*" "CN=data*" "CN=ingest*" ];
    };
  };
  opensearch-node = role: {
    imports = [ ../opensearch-dashboards.nix ];

    boot.kernel.sysctl."vm.max_map_count" = 262144;

    environment.noXlibs = false;
    environment.systemPackages = with pkgs; [ opensearch-fixed jq ];

    systemd.services.opensearch.serviceConfig.ExecStartPre = [
      pkgs.init-keystore
    ] ++ populate-hosts-script;

    services.opensearch = service-config {
      settings."node.roles" = [ role ];
    };
  };
  # We don't know the node IPs in advance
  # so we generate them dynamically.
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
        sed -i "s/ localhost/ $(hostname)/" $CONF
      ''
    }/bin/configure-opensearch"
  ];
in
{
  roles = {
    manager = { pkgs, config, lib, ... }: lib.recursiveUpdate (opensearch-node "cluster_manager") {
      services.opensearch-dashboards.enable = true;
      systemd.services.opensearch.serviceConfig.ExecStartPost = lib.mkForce [
        pkgs.wait-and-run-security-admin
      ];

      # Upload default dashboard configuration
      # TODO: this script was copied from opensearch-mono, de-duplicate it
      systemd.services.opensearch-dashboards.serviceConfig.ExecStartPost = [
        "${pkgs.writeShellScript
        "configure-graphs"
        ''
          while ! ${pkgs.curl}/bin/curl --fail http://localhost:5601/; do
            sleep 1
          done
        
          ${pkgs.curl}/bin/curl -X POST \
            -u admin:admin \
            -H "osd-xsrf: osd-fetch" \
            -H 'osd-version: 2.11.1' \
            -H 'Origin: http://localhost:5601' \
            'http://localhost:5601/api/saved_objects/_import?overwrite=true' \
            --form file=@${./export.ndjson}
        ''}"
      ];
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
              endpoints = [ "https://manager:9200" ];
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
          # The variable "VECTOR_CONFIG" defines the path to the configuration to use when running the `vector` command.
          # The Systemd service generates a config from `services.vector.settings` and ensures that the service uses this file.
          # However, it is also necessary to specify the location of this configuration file to the command line tool available in the PATH.
          # We parse the systemd configuration to retrieve the path to the file.
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
