# OpenSearch mono-nœud

Dossier de la composition : `opensearch-mono/`.

Cette composition fait tourner sur un même nœud :

- l'agrégateur de logs [Vector](https://vector.dev/).
- un serveur [OpenSearch](https://opensearch.org/).
- un serveur [OpenSearch Dashboards](https://opensearch.org/docs/latest/dashboards/quickstart/)

Vector récupère les logs `systemd` de tous les services de la machine
et les stockes dans une base de données (« index ») OpenSearch (une par jour en fait).

OpenSearch Dashboards vient ensuite se connecter à l'API REST d'OpenSearch
et propose une interface graphique pour consulter les données qui sont
stockées dans OpenSearch par Vector. On peut notamment définir des visualisations
et des graphiques pour afficher des statistiques sur les données collectées.

Le serveur OpenSearch écoute sur le port `9200` (pour l'API REST) et
sur le port `9300` (pour les interactions inter-nœuds, pas utile ici).
OpenSearch Dashboards écoute sur le port `5601` : il faut penser à
[forward ce port](../nxc/cheatsheet.md#port-forwarding) (c'est le cas 
automatiquement avec Docker).

Une grande partie du code de la composition est dédié à la configuration
du plugin sécurité d'OpenSearch. Ce plugin est désactivé par défaut dans
le module NixOS, mais OpenSearch Dashboards en a besoin pour authentifier
et autoriser les utilisateurs.

On crée un certificat auto-signé (stocké dans `ssl-keystore.p12`) pour le
serveur OpenSearch, qui servira à chiffrer les connexions à l'API REST et
les échanges entre nœuds. On crée également une liste de certificats de
confiance (dans `ssl-truststore.p12`) qui ne contient qu'un seul certificat :
celui du nœud lui-même.

On crée ces fichiers principalement parce qu'ils sont demandés par le plugin
`security`, en pratique ils ne sont pas (ou très peu) utilisés. En effet,
il n'y a pas de traffic inter-nœuds, et on demande à OpenSearch Dashboards
de ne pas vérifier les certificats.

Pour lancer cette composition sur Grid5000, il faut utiliser le flavour g5k-nfs-store.
Il est possible que l'ouverture des ports SSH prenne quelques dizaines de secondes.

Le flavour g5k-ramdisk fonctionne aussi mais les nœuds ne sont pas accessibles via nxc
connect ou ssh dans ce cas de figure.

Pour interagir avec l'API REST en ligne de commande, on peut utiliser :

```bash
curl -k -u admin:admin https://localhost:9200/
```

`-k` demande d'ignorer les certificats, et `-u admin:admin` permet
de s'authentifier et d'avoir tous les droits.

## Utiliser OpenSearch Dashboards

OpenSearch Dashboards écoute sur le port `5601`. Un tunnel est
automatiquement mis en place avec Docker, mais en VM ou sur un
serveur, il faut [faire un tunnel SSH](../nxc/cheatsheet.md#port-forwarding).

On peut ensuite ouvrir [`http://localhost:5601/`](http://localhost:5601)
dans un navigateur.

On peut se connecter avec l'user `admin` et le mot de passe `admin`.

À la première connection, il sera demandé de choisir un « _tenant_ ».
Il faut choisir « Private » pour avoir accès au Dashboard par défaut.
Si jamais vous avez choisi un autre _tenant_ et que vous voulez changer,
vous pouvez le faire à tout moment en cliquant sur votre avatar en haut
à droite, puis sur « Switch tenants ».

Un dashboard par défaut (assez minimaliste) est disponible.
Pour le voir, cliquer sur « Visualize & analyze » (au centre de
l'écran d'accueil), puis « Dashboard » puis « Vector data ».

Il est possible de modifier ce Dashboard et d'y ajouter des
visualisations. Pour sauvegarder les changements et les
conserver même si la composition est relancée (ce qui efface
toutes les données du système), il faut exporter les données.
Pour celà, aller dans l'onglet « Manage » (en haut à droite
de la page d'accueil), puis « Saved objects » (menu de gauche)
puis exporter tous les objets (« Export X objects », en haut à droite).
Le fichier `export.ndjson` doit être enregistré dans `opensearch-mono/export.ndjson`.
