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
        environment.systemPackages = with pkgs; [ opensearch-fixed jq opensearch-root-cert ] ++ (if enable-vector then [ vector ] else []);

        systemd.services.opensearch.serviceConfig.ExecStartPre = [
          "${pkgs.writeShellScript
          "init-keystore"
          ''
            if [[ -f /var/lib/opensearch/config/ssl-keystore.p12 ]]; then
              exit 0
            fi

            ${pkgs.jre_headless}/bin/keytool \
              -genkeypair \
              -alias opensearch \
              -storepass '${keystore-password}' \
              -dname CN=localhost \
              -keyalg RSA \
              -sigalg SHA256withRSA \
              -keystore /var/lib/opensearch/config/ssl-keystore.p12 \
              -validity 36500

              ${pkgs.jre_headless}/bin/keytool -certreq -alias opensearch -keystore /var/lib/opensearch/config/ssl-keystore.p12 -file /var/lib/opensearch/config/newkey.csr -storepass '${keystore-password}'

              ${pkgs.jre_headless}/bin/keytool -gencert -infile /var/lib/opensearch/config/newkey.csr -outfile /var/lib/opensearch/config/newkey.crt -alias opensearch-root-cert -keystore ${pkgs.opensearch-root-cert}/keystore.p12 -storepass '${keystore-password}'

              ${pkgs.jre_headless}/bin/keytool -importcert -file ${pkgs.opensearch-root-cert}/root.crt -keystore /var/lib/opensearch/config/ssl-keystore.p12 -alias opensearch-root-cert -storepass '${keystore-password}' -noprompt
              
              ${pkgs.jre_headless}/bin/keytool -importcert -file /var/lib/opensearch/config/newkey.crt -keystore /var/lib/opensearch/config/ssl-keystore.p12 -alias opensearch -storepass '${keystore-password}' -noprompt

              cp ${pkgs.opensearch-root-cert}/truststore.p12 /var/lib/opensearch/config/ssl-truststore.p12

          ''}"
        ];
        systemd.services.opensearch.serviceConfig.Restart = lib.mkForce "no";
        systemd.services.opensearch.serviceConfig.ExecStartPost = lib.mkForce [
          "${pkgs.writeShellScript
          "wait-and-run-securityadmin"
          ''
            # wait for opensearch to start
            while ! ${pkgs.nettools}/bin/netstat -tlnp | grep ':9200' ; do
              sleep 1
            done

            ${pkgs.coreutils}/bin/env JAVA_HOME="${pkgs.jre_headless}" \
              /var/lib/opensearch/plugins/opensearch-security/tools/securityadmin.sh \
                -ks /var/lib/opensearch/config/ssl-keystore.p12 \
                -kspass '${keystore-password}' \
                -ksalias opensearch \
                -ts /var/lib/opensearch/config/ssl-truststore.p12 \
                -tspass '${truststore-password}' \
                -cd /var/lib/opensearch/config/opensearch-security
          ''}"
        ];

        services.opensearch = {
          enable = true;
          package = opensearch-fixed;
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
          settings."plugins.security.authcz.admin_dn" = [ "CN=localhost" ];
          settings."plugins.security.ssl.transport.keystore_alias" = "opensearch";
          settings."plugins.security.ssl.transport.keystore_filepath" = "/var/lib/opensearch/config/ssl-keystore.p12";

          # Additional Java options configuration (only for the "opensearch" service)
          # Virtual machines created with `nxc build -f vm` only have 1MB of RAM
          # By default, the JVM asks for more memory than that and cannot start
          # With these options, we limit its RAM usage
          extraJavaOptions = [
            "-Xmx512m" # Limit Java VM memory usage to 512 MB
            "-Xms512m" # Java VM initial memory allocation set to 512 MB
          ];
        };


        # Vector is a log management system
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

        services.colmet-collector.enable = enable-colmet;
        services.colmet-node.enable = enable-colmet;

        environment.variables = lib.mkIf enable-vector {
          # The variable "VECTOR_CONFIG" defines the path to the configuration to use when running the `vector` command.
          # The Systemd service generates a config from `services.vector.settings` and ensures that the service uses this file.
          # However, it is also necessary to specify the location of this configuration file to the command line tool available in the PATH.
          # We parse the systemd configuration to retrieve the path to the file.
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
