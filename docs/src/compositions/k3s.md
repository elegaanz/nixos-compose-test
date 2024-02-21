# K3S

Dossier de la composition : `k3s/`

[K3S](https://k3s.io) est un orchestrateur de container
léger, compatible avec Kubernetes (`k8s`).

Cette composition fait tourner deux nœuds[^g5k] : un serveur K3S et
un agent.

Le serveur est le point d'entrée avec lequel on interagit. Les agents
sont les machines sur lesquelles les containers vont tourner et reçoivent
leurs instructions du serveur.

Le serveur écoute sur le port `6443`.

[^g5k]: sur Grid5000, il faut donc bien penser à [réserver deux nœuds](../nxc/g5k.md#start)
