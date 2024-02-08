{ pkgs, ... }: { 

  roles = { 

    foo = { pkgs, config, lib, ... }:  

      {  

        environment.systemPackages = with pkgs; [ opensearch vector ]; 

        services.opensearch.enable = true;  

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

        services.opensearch.extraJavaOptions= [  # Configuration des options Java supplémentaires pour le service "opensearch"
          "-Xmx512m"  # Limite maximale de la mémoire utilisée par la machine virtuelle Java à 512 Mo
          "-Xms512m"  # Mémoire initiale allouée par la machine virtuelle Java à 512 Mo
        ];

        environment.variables = {  # Définition des variables d'environnement
          VECTOR_CONFIG = lib.lists.last (  # La variable "VECTOR_CONFIG" est définie comme le dernier élément de la liste obtenue en divisant la chaîne "config.systemd.services.vector.serviceConfig.ExecStart" par des espaces
            builtins.split " " config.systemd.services.vector.serviceConfig.ExecStart
          );
        };
      };  
  };

  testScript = ''  
    foo.succeed("true")
  '';
}