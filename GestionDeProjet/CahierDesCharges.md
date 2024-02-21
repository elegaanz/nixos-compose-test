<style>
h1 {
    color: #FF6347 !important;
}

h2 {
    color: #FFA500 !important;
}
    
h3 {
    color: #9ACD32 !important;    
}
    
h4 {
    text-decoration: underline;
    color: #87CEEB !important;
}
</style>

# I - CAHIER DES CHARGES

## 1. CONTEXTE ET ENJEUX

NixOS-compose est un outil permettant la création et le déploiement de piles logicielles reproductibles. Cet outil est développé par des chercheurs et des doctorants du LIG. En se basant sur le langage Nix et le système d'exploitation NixOS, cet outil peut être utilisé pour créer des containers, des machines virtuelles, ou des images utilisables sur l'infrastructure Grid5000.

L'outil étant suffisament avancé, les chercheurs du LIG ont besoin de retours sur l'utilisabilité du logiciel, des problèmes rencontrés, et de fichiers utilisables en conditions réelles. Notre rôle est d'écrire ces fichiers pour éprouver l'outil et faire nos retours sur les éventuels problèmes rencontrés.

## 2. OBJECTIFS (ET EXIGENCES FONCTIONNELLES)

### 2.1 - Les grandes étapes du projet

Différentes étapes à voir comme une suite, avec l'une qui dépend de la précédente, ce projet est expérimental et incrémental donc cela suppose que l'objectif peut aussi d'être de repérer des bugs ou erreurs. 

Voici la liste des différentes étapes : 

- Opensearch en mono
- Opensearch avec Vector en local
- Opensearch avec Vector sur Grid'5000
- Opensearch en multi
- Opensearch (en multi) avec Vector en local
- Opensearch (en multi) avec Vector Grid'5000
- Ajouter OpenSearch dashboards

D'autre part :

- k3s en version 23.11 de NixOS, en local et sur Grid'5000, une version 23.05 est existante. 


### 2.2 - Exigences fonctionnelles :

- S'assurer que toutes les compositions proposées se lancent sur les différentes machines.

- Opensearch en mono :
    - Configuration simple d'Opensearch sur un seul nœud.
    - Possibilité de rechercher, indexer et analyser des données.
    - Prise en charge des requêtes de recherche, y compris des requêtes complexes.
    - Capacité à gérer les index et les types de données.

- Opensearch avec Vector en local :
    - Intégration de Vector pour la collecte, l'analyse et la visualisation des données.
    - Capacité à configurer et à gérer des pipelines de traitement des données avec Vector.

- Opensearch avec Vector sur Grid'5000 :
    - Capacité à déployer Opensearch avec Vector sur un cluster Grid'5000.

- Opensearch en multi :
    - Configuration d'Opensearch sur plusieurs nœuds pour une haute disponibilité et une répartition de charge.
    - Capacité à gérer la synchronisation des données entre les nœuds pour assurer la cohérence.

- Opensearch (en multi) avec Vector en local :
    - Combinaison des fonctionnalités multi-nœuds d'Opensearch avec l'intégration de Vector pour l'analyse et la visualisation des données.
    - Capacité à gérer la distribution des tâches de traitement des données entre les nœuds.

- Opensearch (en multi) avec Vector sur Grid'5000 :
    - Déploiement d'un cluster Opensearch multi-nœuds avec Vector sur Grid'5000.
    - Capacité à gérer la charge de travail distribuée sur le cluster pour l'ingestion, l'analyse et la visualisation des données.

- k3s en version 23.11 de NixOS, en local et sur Grid'5000, une version 23.05 est existante :
    - Rapport sur la compatibilité / les bugs / ect.

Il est important de noter que dans tout le projet, la phase de recherche de bugs / erreurs / warnings, ainsi que la production de rapports d'erreur fait partie intégrante du projet.

## 3. PROCESSUS DE VALIDATION

Quant à la validation de nos systèmes nous allons utiliser des nixos-test et la section testScript dans les fichiers de composition pour lancer des tests sur nos machines.
L'objectif étant d'avoir des systèmes disponibles pour des utilisations personnalisées, les tests ont pour but de valider que le système est fonctionnel pour une utilisation la plus classique possible. De cette manière, on laisse la possibilité aux utilisateurs de modifier / personnaliser notre système. 


