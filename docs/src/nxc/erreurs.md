# Erreurs communes

## La commande `nix` ne marche pas

Message d'erreur :

```bash
error: experimental Nix feature 'nix-command' is disabled; add '--extra-experimental-features nix-command' to enable it
```

Pour régler le souci, on peut ajouter les arguments à chaque commande qu'on tape
comme expliqué dans le message d'erreur, ou les ajouter dans la config Nix pour
que ça soit fait automatiquement. Il faut rajouter cette ligne dans `~/.config/nix/nix.conf` :

```
experimental-features = nix-command
```

Il y aura sans doute besoin de la feature `flakes` aussi, donc autant mettre cette ligne plutôt :

```
experimental-features = nix-command flakes
```

## CGroups V2

*À rédiger*

## Beaucoup de paquets sont recompilés

Parfois quand on compile avec `nxc build`, beaucoup de paquets sont
recompilés au lieu d'être récupérés depuis le cache binaire.

Une des raisons qui peut causer ces *cache-miss* est que NixOS-compose
désactive X11 par défaut, alors qu'il est activé sur Hydra (et donc dans
les paquets stockés dans le cache binaire). Cette différence se répercute
dans les dépendances de certains paquets (compilés ou non avec le support
de X11) et change donc leur hashs.

Pour contourner le souci, on peut réactiver X11 en ajoutant cette option
dans sa composition :

```nix
environment.noXlibs = false;
```

Les images générées par `nxc` seront un tout petit plus lourde, car quelques
bibliothèques en plus seront présentes, mais la différence devrait être
négligeable.
