{ pkgs, ... }: {
  roles = {
    opensearch = { pkgs, config, lib, ... }:
      {
        environment.systemPackages = with pkgs; [ opensearch vector ];

        services.opensearch = {
          enable = true;
          # Configuration des options Java supplémentaires (uniquement pour le service "opensearch")
          # Les machines virtuelles créées avec `nxc build -f vm` n'ont qu'un Mo de mémoire vive
          # Par défaut, la JVM demande plus de mémoire que ça et ne peut pas démarrer
          # Avec ces options, on limite son utilisation de la RAM
          extraJavaOptions = [
            "-Xmx512m"  # Limite maximale de la mémoire utilisée par la machine virtuelle Java à 512 Mo
            "-Xms512m"  # Mémoire initiale allouée par la machine virtuelle Java à 512 Mo
          ];
        };

        # Vector est système de gestion de logs
        services.vector = {
          enable = true;
          settings = {
            sources = {
              "in" = {
                type = "stdin";
              };
            };
            sinks = {
              out = {
                inputs = ["in"];
                type = "console";
                encoding = {
                  codec = "text";
                };
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
  };

  testScript = ''
    foo.succeed("true")
  '';
}