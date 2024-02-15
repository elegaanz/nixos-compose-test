{ pkgs, ... }: {
  roles = {
    opensearch = { pkgs, config, lib, ... }:
      {
        imports = [ ../opensearch-dashboards.nix ];

        environment.noXlibs = false;
        environment.systemPackages = with pkgs; [ opensearch vector jq ];

        services.opensearch = {
          enable = true;
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
                endpoints = [ "http://localhost:9200" ];
              };
            };
          };
        };

        services.opensearch-dashboards.enable = true;

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
  };

  dockerPorts.opensearch = [ "5601:5601" "9200:9200" ];

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
