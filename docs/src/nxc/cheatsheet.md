# Anti-sèche

## Travailler sur une composition

```bash
cd DOSSIER-DE-LA-COMPOSITION
nix develop
nxc build -f FLAVOUR
nxc start
nxc connect ROLE
```

## Lancer les tests

```bash
nxc start
# Bien attendre que la machine soit démarrée, puis
nxc driver -t
```

## Accéder à un service en TCP / HTTP { #port-forwarding }

Pour accéder à un service qui tourne dans une VM qemu,
on peut faire un tunnel SSH (à la place de faire `nxc connect ROLE`).

```bash
ssh -L PORT:localhost:PORT root@localhost -p 22022
```

Le port 22022 est à remplacer avec le port SSH de la machine (22022 est le premier,
puis on a 22023, etc).

En théorie, on peut aussi ajouter des arguments à QEMU pour qu'il fasse le forwarding,
mais en pratique ça ne marche pas :

```bash
env QEMU_OPTS="-netdev user,id=n0,hostfwd=tcp::PORT-:PORT" nxc start
```

Si jamais les VM QEMU ont du mal à tourner, on peut essayer d'activer
explicitement KVM avec la variable d'environnement `QEMU_OPTS=--enable-kvm`.
On peut aussi ajouter de la mémoire avec `MEM=2048` (en Mio, par défaut il y en 1024).

Une fois qu'un port est « forwardé », on peut y accéder depuis la machine
hôte, par exemple en ouvrant `http://localhost:PORT` dans un navigateur,
ou en utilisant `curl`.
