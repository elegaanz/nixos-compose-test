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

Avec Docker, il arrive que les containers ne se lancent pas, sans faire de
message d'erreur.

[Ce problème est connu](https://gitlab.inria.fr/nixos-compose/nixos-compose/-/issues/9).

Pour contourner le problème, il faut désactiver `cgroups` V2 en
[ajoutant ces options au Noyau Linux](https://wiki.archlinux.org/title/Kernel_parameters),
sur la machine hôte: `systemd.unified_cgroup_hierarchy=0`.

Cette solution a marché pour des machines sous ArchLinux, mais semble insuffisante
si on est sous Ubuntu (dans ce cas nous avons préféré utiliser les VM Qemu).

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
