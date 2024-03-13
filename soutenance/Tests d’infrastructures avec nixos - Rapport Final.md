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

<div style="display: flex; gap: 5rem; align-items: center">

![](https://blog.stephane-robert.info/img/nixos-logo.webp =200x)
    
![](https://polytech.grenoble-inp.fr/uas/polytech/LOGO/logo_inp_polytech_2023grenoble.png =500x)

![](https://upload.wikimedia.org/wikipedia/fr/b/ba/Logo_LIG.png)

</div>



# Tests d’infrastructures avec nixos - Rapport Final

## Rapport
### Notre Equipe
#### De Polytech :
* Ana GELEZ - Chef de projet
* Dorian MOUNIER - développeur
* Mathis GRANGE - développeur
* Elise DUPONT - développeuse

#### Du LIG (Laboratoire d'informatique de Grenoble):
* Olivier RICHARD - responsable
* Quentin Guilloteau - debuggeur à distance

### Contexte et outils

#### Nix

Nix est un langage de programmation permettant d’installer et de configurer des logiciels. C'est aussi un gestionnaire de paquets pour les systèmes GNU/Linux. Ce gestionnaire a de nombreux avantages : 

* Reproductibilité : Les paquets sont construits à partir de sources avec des dépendances figées ce qui garantit des installations identiques à chaque fois.
* Fiabilité : L'installation d'un paquet n'affecte jamais les autres paquets installés.
* Isolation : Chaque paquet est encapsulé dans son propre environnement, ce qui permet d'installer plusieurs versions du même paquet simultanément.
* Déclarativité : La configuration du système est déclarative, ce qui facilite la gestion, la maintenance et la transparence du système.

#### NixOS
NixOS est le système d'exploitation basé sur Nix. Ce système d'exploitation a tous les avantages du gestionnaire de paquet Nix en plus des suivants : 

* Mises à jour fiables : Les mises à jour sont appliquées de manière atomique ce qui les empêche de corrompre le système.
* Rétrogradation : Les retours en arrière après une installation sont simples.
* Encapsulation : On peut créer des environnements utilisateur ou des logiciels isolés.
* Grand choix de paquets: NixOS propose un large choix de paquets, y compris des logiciels populaires et des outils de développement.

#### NixOS-Compose
NixOS-Compose est un outil développé au LIG permettant la création de systèmes NixOS pré-configurés. Il va permettre de réduire la charge des systèmes distribués éphémères et d'étendre l'utilisation de NixOS sur d'autre supports comme par exemple les machines virtuelles.

![](https://cdn.discordapp.com/attachments/805803410493538324/1216783917424836608/nixosCompose.png?ex=6601a554&is=65ef3054&hm=b2b04862015742e8c446d24b921c82ae95cd7c120744ec72ad84b652d790a970&)

#### Nixpkgs et Nur-Kapack
Nixpkgs et NUR sont des dépôts de paquets Nix. Ils sont utilisés
massivement par le gestionnaire de paquets, en tant que collection de paquets et logiciels installables par les utilisateurs possédant Nix. 

#### Grid'5000

Grid'5000 est un réseau européen de machines disponibles pour la recherche. Nous avons pu en réserver une ou plusieurs pour un temps donné et déployer nos compositions Nix dessus. Les machines sont nettoyées une fois leur utilisation terminée. 

Ceci avait plusieurs objectifs, premièrement faire un test à plus grande échelle avec des machines plus performantes et la possibilité de lancer sur plus de noeuds. De plus, le déploiement sur l'outil est un peu différent en vue de l'architecture, comparé aux tests sur nos machines. Enfin, notre projet sera utilisé principalement sur cet outil donc il est essentiel de tester chacune de nos compositions sur Grid'5000.

#### Github 

Nous utilisons Github pour le versionning et la mise en commun du code ainsi que Github Actions pour compiler la documentation et la déployer en ligne. Nous avons également utilisé les "Issues" de Github afin de noter les prochaines étapes à faire ainsi que les problèmes actuels. Nous nous sommes aussi servi du service Kanban intégré à Github car notre projet se prêtait
très bien aux méthodes agiles : nous avions des sprints d'une semaine avec des points chaque lundi avec le porteur du projet, au cours desquels nous faisions un point sur notre avancé et nous revoyions nos objectifs. 

### Composition

Notre projet consiste à réaliser des configurations NixOS, appelées compositions, et à les tester. Une composition est une pile de logiciels configurés pour fonctionner ensemble que l'on va mettre à disposition dans un système NixOS pour une utilisation dans la recherche.

Voici un schéma des fichiers contenus dans une petite composition:

![](https://cdn.discordapp.com/attachments/805803410493538324/1216784697229836298/Capture_decran_du_2024-03-06_09-53-39.png?ex=6601a60e&is=65ef310e&hm=bf6362b3c81d4cc9e4cd967ceb7d012e0cea6f85d2ddfe13c612a42617069b93&)

Le fichier le plus important est `compositon.nix`. C'est ici qu'on configure notre système. Par exemple, si on veut faire tourner une machine avec le serveur web Nginx, on peut écrire cette composition :

```nix,=
{ pkgs, lib, ... }:
{
  roles = {
    server = { pkgs, config, lib, ... }: {
      services.nginx.enable = true;
    }
  };
}
```

On utilise ensuite l'outil `nxc` (abbréviation de NixOS-Compose) pour lancer notre composition sur notre machine (dans une machine virtuelle), et la tester. Une fois qu'elle fonctionne comme on le souhaite, on la teste sur Grid'5000.

### Objectifs du projet

Voici le WBS du projet. On observe les tâches réalisées et celles qui restent à faire pour la suite du projet. Nous avions comme objectif de réaliser des compositions et de les tester.

![](https://cdn.discordapp.com/attachments/805803410493538324/1217500770207924344/BSW_final.svg?ex=660440f3&is=65f1cbf3&hm=fd60274b59ad2835faed895ad639b43a60e78f37b733f28e3a5405e58965f9d7&)

### Composition Opensearch

Notre projet principal était de réaliser plusieurs compositions utilisant Opensearch. L'objectif était de combiner ce logiciel à un collecteur de données comme Vector ou Colmet ainsi qu'à une interface de visualisation de ces données, Opensearch Dashboards. Opensearch Dashboards permet d'afficher les données récupérées par le collecteur sous forme de graphes.
Dans notre cas, les données collectées sont des logs, c'est-à-dire des journaux informatiques d'un système en fonctionnement.

![](https://cdn.discordapp.com/attachments/1200028901792022628/1214860978722963487/Capture_decran_du_2024-03-06_10-03-30.png?ex=65faa674&is=65e83174&hm=1129f91c979efe7dd72b15296c041c902e317c92d38aca32d107262d6e79d31e&)

Nous avons réalisé et testé plusieurs formes de compositions. Tout d'abord utilisant un seul noeud, c'est-à-dire que tout les logiciels fonctionnent sur la même machine. Puis avec pusieurs noeuds afin de répartir la charge et d'adapter le système à une utilisation sur des grands volumes de données.

Voici une composition en multi-noeud que nous avons réalisé:

![](https://cdn.discordapp.com/attachments/1200028901792022628/1214872646928437248/Capture_decran_du_2024-03-06_10-49-48.png?ex=65fab152&is=65e83c52&hm=c67f4eae038fa2c23f2ace94936d4d3e77f57240d410278d173ba35af42136ad&)

### Composition K3S

<img src="https://blog.stephane-robert.info/img/logo-k3s.png" style="float: right; margin: 1em 2em" />

K3S est une version simplifiée et allégée de Kubernetes, tout en offrant les fonctionnalités principales d'orchestration de conteneurs. Une version minimale était déjà proposée dans une ancienne version de NixOS-Compose. Notre objectif était de tester cette dernière et si besoin, de l'adapter aux nouvelles versions de Nix, NixOS et NixOS-Compose. Ainsi que de réaliser des tests sur Grid'5000. Nous avons pour cela créé une documentation pour faciliter une future utilisation de notre projet.

### Documentation générale et spécifique


Nous avons créé une documentation qui présente le fonctionnement du projet, les erreurs fréquentes, comment lancer les compositions, etc. qui permet de comprendre et reprendre notre projet sans devoir refaire le travail de recherche et de compréhension que nous avons déjà effectué.

La documentation est mise en ligne automatiquement à chaque changement, à l'adresse suivante : <https://elegaanz.github.io/nixos-compose-test/>

Voici un exemple pour le début de la page dédiée à Grid'5000 :

![](https://cdn.discordapp.com/attachments/1200028901792022628/1217043091291377805/Capture_decran_du_2024-03-12_10-33-29.png?ex=660296b4&is=65f021b4&hm=695a28d5b3bb882f26a0e2d4b02245014662cd0d9d5e474d0a7b0dfb8f806654&)


### Projets annexes
Pour le bon déroulement de notre projet, nous avons été amenés à contribuer à d'autres projets annexes.

#### oar-team/nur-kapack : 
Nous avons mis à jour le paquet Colmet et ses dépendances pour résoudre des bugs et lui permettre de fonctionner dans nos compositions.

#### oar-team/colmet : 
Nous avons résolu un bug avec les versions récentes de ZeroMQ.

#### oar-team/nixos-compose : 
Nous avons résolu un bug de compatibilité avec les Linux non-NixOS et changé de configuration pour avoir une meilleure utilisation du cache de compilation.

### Suivi de Projet

Nous avons utilisé Gantt pour planifier notre projet et prévoire le temps qu'il nous faudrait pour réaliser nos tâches. 

#### Légende :
* <span style="color: #800080; background-color: #800080;">teste</span> : Découverte Nix, NixOS et NixOS-compose
* <span style="color: #4682B4; background-color: #4682B4;">teste</span> : Compositions réalisées
* <span style="color: #42CD32; background-color: #42CD32;">teste</span> : Tests réalisés
* <span style="color: #FF8C00;background-color: #FF8C00;">teste</span> : Gestion de projet
* <span style="color: #FF0000; background-color: #FF0000;">teste</span> : Parties optionnelles non réalisées
* 🔴 : Soutenances

#### Gantt : 
![](https://cdn.discordapp.com/attachments/805803410493538324/1217104006233587742/Test_dinfrastuctures_avec_NixOS.png?ex=6602cf6f&is=65f05a6f&hm=b10a798d7428f1587445742b630c930b2b8feeb236e99e43ff9a54eed3926457&)


### Métriques Logicielles
Nous avons réalisé 75 commits en tout.

```
===============================================================================
 Language            Files        Lines         Code     Comments       Blanks
===============================================================================
 JSON                    3            3            3            0            0
 Nix                    10          718          217          474           27
 TOML                    1            6            6            0            0
-------------------------------------------------------------------------------
 Markdown               13          427            0          289          138
 |- BASH                 6           43           30           12            1
 |- Nix                  1            1            1            0            0
 (Total)                            471           31          301          139
===============================================================================
 Total                  27         1154          226          763          165
===============================================================================
```

## Glossaire

* Noeud Grid'5000 : Machine disponible sur le réseau Grid'5000

* Composition : Ensemble de fichiers décrivant un système NixOS avec un assemblage de logiciels et leurs configurations

* Machine virtuelle : Ordinateur simulé qui peut exécuter son propre système d'exploitation et ses propres applications, créé à l'intérieur d'un ordinateur physique à l'aide d'un logiciel de virtualisation.

## Bibliographie


#### NixOS

* **Moteur de recherche pour nixpkgs et les options NixOS:** https://search.nixos.org/packages
* **Tutoriel installation de nix:** https://zero-to-nix.com/start/install
* **Wiki NixOS:** https://nixos.wiki/wiki/Main_Page
* **NixOS & Flakes Book:** https://nixos-and-flakes.thiscute.world/introduction/
* **Fonction de la bibliothèque standard:** https://teu5us.github.io/nix-lib.html
* **Github nur-kapack:** https://github.com/oar-team/nur-kapack
   
#### NixOS-compose

* Quentin Guilloteau, Jonathan Bleuzen, Millian Poquet, Olivier Richard. **Painless Transposition of Reproducible Distributed Environments with NixOS Compose** CLUSTER 2022 - IEEE International Conference on Cluster Computing, Sep 2022, Heidelberg, Germany. pp.1-12. ⟨hal-03723771v2⟩
* **Tutoriel "en travaux" (à jour mais incomplet):** https://nixos-compose.gitlabpages.inria.fr/nixos-compose/index.html
* **Tutoriel "pas en travaux" (pas à jour mais plus complet):** https://nixos-compose.gitlabpages.inria.fr/tuto-nxc/01_intro.html
  
#### Autres
* **Documentation opensearch et opensearch-dashboard:** https://opensearch.org/docs/latest/
* **Package Colmet + documentation:** https://github.com/oar-team/colmet
* **Documentation K3S:** https://docs.k3s.io/