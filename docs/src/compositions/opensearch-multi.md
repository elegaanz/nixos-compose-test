# OpenSearch multi-nœud


=======
Quatre rôles existent :

- `vector` qui fait tourner vector, connecté à OpenSearch
- `manager`, nœud OpenSearch manager
- `ingest`, nœud OpenSearch ingest (uniquement, pas de data)
- `data`, nœud OpenSearch data

## Note pour Docker

Le cluster peut ne pas démarrer avec Docker, avec le message d'erreur
suivant dans les logs d'OpenSearch (`systemctl status opensearch.service`).

```
max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
```

Cette option est une option du noyau Linux qui peut être configurée avec
`sysctl`. Dans les autres flavours, elle est configurée via NixOS dans
le code de la composition, mais dans le cas de Docker, comme le noyau
est partagé avec la machine hôte, on doit changer l'option manuellement
sur sa machine.

En dehors des containers, il faut donc faire :

```bash
sudo sysctl -w vm.max_map_count=262144
```

## Lancer plusieurs nœuds du même type

Pour lancer plusieurs même noeud à partir d'un code on utilise la commande : 

```
nxc start -r nom_du_noeud=nombre_de_noeud -f vm
```

Par exemple, on peut lancer la commande suivante pour avoir 2 noeuds data identique : `nxc start -r data=2 -f vm`

