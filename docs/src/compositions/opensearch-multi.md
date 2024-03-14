# OpenSearch multi-nœud

Quatre rôles existent :

- `vector` qui fait tourner vector, connecté à OpenSearch
- `manager`, nœud OpenSearch manager, qui fait aussi tourner OpenSearch Dashboards
- `ingest`, nœud OpenSearch ingest (uniquement, pas de data)
- `data`, nœud OpenSearch data

*Note : nous n'avons pas eu le temps de finir l'intégration de Colmet
dans cette configuration, mais les premiers pas on été faits dans la
branche `multi_colmet`.*

La plupart des informations valable pour [Opensearch mono-nœud](./opensearch-mono.md)
sont aussi valable pour cette composition (connexion à OpenSearch Dashboards et
à l'API, tunnel SSH, dashboards par défaut).

## Sécurité

Les échanges entre les nœuds sont chiffrés avec TLS. Pour celà, nous avons
mis en place une chaîne de certification. Un certificat racine est
généré au moment de la compilation (derivation `opensearch-root-cert`
dans l'overlay `opensearch-security.nix`). Grâce à des scripts bash
exécutés par Systemd au lancement d'OpenSearch, des certificats pour chaque
nœuds sont ensuite générés et configurés lors du démarrage des machines.
Ces certificats de nœuds sont signés par le certificat racine (et placés
dans le `keystore`). Le certificat racine est listé comme étant de confiance
(en étant copié dans le `truststore` de chaque nœud, mais aussi en étant
ajouté à la liste des certificats du système).

Sur le nœud manager, un script pour configurer les permissions et utilisateurs
par défaut est également lancé (`wait-and-run-secyrityadmin`). Afin d'avoir
des droits d'administration, ce script a également besoin d'un certificat pour
s'authentifier. Nous en générons donc un et le signons avec le même certificat
racine.

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

