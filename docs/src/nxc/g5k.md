# Grid5000

Pour configurer les alias SSH, [voir le wiki Grid5000](https://www.grid5000.fr/w/SSH#Easing_SSH_connections_from_the_outside_to_Grid'5000).

## Envoyer une composition sur Grid5000

On a deux options.

### Option 1 :Copier les fichiers

```bash
scp -r DOSSIER-DE-LA-COMPO VILLE.g5k:~
```

### Option 2 : Cloner le dépôt Git

Il faut s'assurer que tous les changements dont on a besoin
on été `commit` et `push` sur GitHub. Ensuite, on fait un
`clone` classique (en utilisant l'URL HTTPS du dépôt, pas SSH).

## Connexion au serveur d'accueil de la ville

```bash
ssh VILLE.g5k
```

## Installation de `nxc` sur le Grid5000

À la première connexion, il faut installer `nxc` avec :

```bash
# On installe poetry, un gestionnaire de projet et de
# dépendances pour Python, utilisé par nxc
curl -sSL https://install.python-poetry.org | python3 -
# On fait en sorte que poetry soit accessible dans le shell
export PATH=$PATH:~/.local/bin
# On récupère le code source de nxc
git clone https://github.com/oar-team/nixos-compose.git
cd nixos-compose
# On installe les dépendances
poetry install
# On entre dans un shell où l'exécutable nxc est disponible
poetry shell
# On installe Nix (cette commande l'installe pour l'utilisateur
# courant seuleument, en téléchargeant une version pré-compilée
# et ne demande donc pas de droits particuliers) 
nxc helper install-nix
```

## Mise en place automatique

À chaque connexion, il faut taper les commandes suivantes,
pour s'assurer que tous les exécutables dont on a besoin sont
disponibles :

```bash
export PATH=~/.local/bin:$PATH
exec poetry shell -C nixos-compose
```

Il est possible d'ajouter ces commandes à la fin du fichier `~/.profile`
pour qu'elles soient exécutées automatiquement à chaque nouvelle connexion.

## Compiler et lancer la composition { #start }

```bash
nxc build -f g5k-ramdisk

# Modifier nodes=1 pour réserver le nombre de nœuds dont
# on a besoin
export $(oarsub -l nodes=1,walltime=1:0:0 "$(nxc helper g5k_script) 1h" | grep OAR_JOB_ID)
oarstat -u -J | jq --raw-output 'to_entries | .[0].value.assigned_network_address | .[]' > machines
nxc start -f g5k-ramdisk -m machines
```

Si vous avez une erreur par rapport au `flake/linux_x86_64`, il faut `exit` et se reconnecter (aucune idée
de pourquoi ça règle le souci).

## Réserver un nœud et s'y connecter

```bash
oarsub -I
```

## Annuler une réservation de nœud

```bash
oardel $OAR_JOB_ID
```
