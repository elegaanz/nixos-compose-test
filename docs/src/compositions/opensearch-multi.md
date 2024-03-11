# OpenSearch multi-nœud

Composition à faire.

Pour lancer plusieurs même noeud à partir d'un code on utilise la commande : 

```nxc start -r nom_du_noeud=nombre_de_noeud -f vm ```

Par exemple : 

Avec le code du noeud data :

```
    data = { pkgs, config, lib, ... }: {
      boot.kernel.sysctl."vm.max_map_count" = 262144;

      environment.noXlibs = false;
      environment.systemPackages = with pkgs; [ opensearch-fixed ];

      systemd.services.opensearch.serviceConfig.ExecStartPre =
        populate-hosts-script;

      services.opensearch = service-config {
        settings."node.name" = config.networking.hostName;
        settings."node.roles" = [ "data" ];
      };
    };
  };
```

On peut lancer la commande suivante pour avoir 2 noeuds data identique : ``` nxc start -r data=2 -f vm ```


