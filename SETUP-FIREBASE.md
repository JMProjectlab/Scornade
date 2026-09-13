# Mise en place de Firebase

Le code est prêt : il ne reste que les étapes qui demandent ton compte Google et
Xcode. Tant qu'elles ne sont pas faites, **l'application démarre et fonctionne
normalement en local** — `FirebaseSupport` détecte l'absence de configuration et
désactive simplement la synchronisation.

## 1. Créer le projet Firebase

Sur <https://console.firebase.google.com> → **Ajouter un projet**.

> **Choix irréversible :** à la création de la base Firestore, sélectionne
> l'emplacement **`eur3` (europe-west)**. On ne peut pas en changer ensuite sans
> recréer le projet, et la politique de confidentialité annonce un hébergement
> dans l'Union européenne.

Puis :

- **Build → Firestore Database → Créer une base** — mode production, région `eur3`.
- **Build → Authentication → Get started** — activer les fournisseurs **Apple**
  *et* **Google**. Les deux sont obligatoires : l'application n'a plus de mode
  invité, et la règle 4.8 d'Apple impose « Se connecter avec Apple » dès lors
  qu'un autre service de connexion tiers est proposé.

> **Le fournisseur Apple demande deux niveaux d'effort selon la cible.**
>
> Pour l'**app iOS**, il suffit de l'activer : rien d'autre à renseigner, Apple
> et Firebase s'entendent via le bundle identifier.
>
> Pour le **site web**, Firebase réclame en plus un **Services ID**, ton **Team
> ID**, un **Key ID** et une **clé privée `.p8`**, tous à créer côté
> <https://developer.apple.com> (Certificates, Identifiers & Profiles). C'est
> une demi-heure de manipulations, et la clé privée ne se télécharge qu'une
> seule fois.
>
> Rien n'oblige à tout faire d'un coup : le site peut très bien sortir avec la
> **connexion Google seule** — la règle 4.8 d'Apple encadre l'App Store, pas un
> site web. Il suffit alors de masquer le bouton Apple dans `docs/assets/ui.js`
> en attendant. L'app iOS, elle, a besoin des deux, mais sans cette paperasse.

## 2. Enregistrer l'application iOS

Dans les réglages du projet → **Ajouter une application** → iOS.

- Identifiant du bundle : `JMProject.Scornade`
- Télécharger **`GoogleService-Info.plist`**
- Le glisser dans Xcode, dans le dossier `Scornade/Scornade/`, en cochant
  « Copy items if needed » et en visant la cible **Scornade**

Ce fichier contient des identifiants propres à ton projet. Il n'est pas secret au
sens d'un mot de passe (il part dans chaque copie de l'app), mais il n'a rien à
faire dans un dépôt public : `.gitignore` l'exclut déjà.

## 3. Ajouter le SDK Firebase

Dans Xcode : **File → Add Package Dependencies…**

- URL : `https://github.com/firebase/firebase-ios-sdk`
- Règle de version : « Up to Next Major »
- Cocher uniquement ces trois produits, pour ne pas alourdir l'app :
  - `FirebaseAuth`
  - `FirebaseFirestore`
  - `FirebaseCore` *(ajouté automatiquement par les deux précédents)*

Puis un **second paquet**, pour la connexion Google :

- URL : `https://github.com/google/GoogleSignIn-iOS`
- Produit : `GoogleSignIn`

> Je n'ai pas fait cette étape à ta place volontairement : ajouter une
> référence de paquet en modifiant `project.pbxproj` à la main, sans pouvoir
> ouvrir Xcode pour vérifier, risque de produire un projet qui refuse de
> s'ouvrir. Trente secondes dans l'interface, et c'est fiable.

## 3 bis. Déclarer le schéma d'URL de Google

Sans cette étape, la feuille de connexion Google s'ouvre mais ne revient jamais
dans l'application.

1. Ouvre `GoogleService-Info.plist` et copie la valeur de **`REVERSED_CLIENT_ID`**
   (elle ressemble à `com.googleusercontent.apps.1234567890-abcdef`).
2. Dans Xcode, cible Scornade → onglet **Info** → **URL Types** → **+**
3. Colle cette valeur dans le champ **URL Schemes**.

Je ne peux pas préparer ce réglage : la valeur est propre à ton projet Firebase
et n'existe que dans le fichier que tu vas télécharger.

## 4. Publier les règles de sécurité

Le fichier `firestore.rules` à la racine du dépôt contient les règles à appliquer.
Copie son contenu dans **Firestore Database → Règles**, puis **Publier**.

Sans cette étape, la base reste soit fermée à tout le monde, soit — pire —
ouverte à tous si tu as choisi le mode test à la création.

Ces règles couvrent deux choses : les données de chaque compte, cloisonnées par
identifiant, et la collection `games` — le catalogue, commun à tous et en
**lecture seule**. Aucun client ne peut y écrire, même authentifié.

Les jeux créés dans l'application, eux, appartiennent à leur auteur : ils vivent
sous `users/{uid}/customGames/{id}`, au même titre que ses joueurs et ses
parties. Ce n'est pas le catalogue commun, et personne d'autre ne les voit.

## Corriger une règle de jeu sans republier l'application

C'est l'intérêt de la collection `games`. Un libellé maladroit ou une faute dans
les règles se corrigent depuis la console, et les deux clients l'appliquent au
prochain lancement — sans passer par la validation App Store, qui prend des
jours.

**Dans la console : Firestore Database → Démarrer une collection → `games`.**

L'**identifiant du document** doit être celui du jeu, exactement comme dans le
code : `belote`, `coinche`, `tarot`, `papayoo`, `rami`, `uno`, `skyjo`,
`scrabble`, `flechettes`, `petanque`, `billard`, `yams`, `421`, `manille`,
`backgammon`, `bowling`, `poker`, `dominos`, `millebornes`, `molkky`.

Quatre champs sont acceptés, tous facultatifs — on ne met que ce qu'on corrige :

| Champ | Type | Effet |
|---|---|---|
| `rules` | chaîne | Le texte des règles. Les sauts de ligne sont conservés. |
| `name` | chaîne | Le nom affiché du jeu. |
| `category` | chaîne | `cartes`, `societe`, `sport` ou `des`. |
| `defaultTarget` | nombre | L'objectif proposé à la création d'une partie. |

Un document `tarot` ne contenant que `rules` corrige les règles du tarot et ne
touche à rien d'autre.

> **Ce qui n'est délibérément pas modifiable à distance :** le moteur de calcul,
> le mode équipe et le sens de victoire. Le moteur désigne une vue de saisie et
> une fonction de calcul — c'est du code, pas une donnée. Quant au sens de
> victoire, le vainqueur est recalculé à chaque affichage : l'inverser
> réécrirait le résultat de parties déjà terminées et archivées.
>
> Un identifiant inconnu est ignoré, et un champ vide ou du mauvais type aussi.
> Une faute de frappe dans la console ne peut donc pas casser l'application :
> au pire, la correction ne s'applique pas.

**Une collection `games` vide est le cas normal.** Tant que tu ne corriges rien,
c'est le catalogue livré avec l'application qui sert — c'est lui qui fait foi au
premier lancement et hors ligne. Les corrections reçues sont mises en cache
localement, donc elles survivent à une coupure réseau.

## 5. Capacités Xcode

Dans **Signing & Capabilities** de la cible Scornade :

- **Sign in with Apple** doit être présent (le fichier d'entitlements le déclare déjà)
- **iCloud / CloudKit n'est plus utilisé** : si la capacité est encore là, retire-la

## 6. Vérifier

1. Lancer l'app, se connecter avec Apple, créer une partie.
2. Dans la console Firebase → Firestore, la partie doit apparaître sous
   `users/{ton-uid}/sessions/{id}`.
3. Passer l'appareil en mode avion, saisir des manches, revenir en ligne :
   Firestore rejoue les écritures en attente tout seul.
4. Tester « Supprimer mes données » : les documents **et** le compte
   Authentication doivent disparaître (c'est ce qu'exige la règle 5.1.1(v)
   d'Apple sur la suppression de compte).

## La connexion est obligatoire

Il n'y a plus de mode invité : on entre dans l'application par Apple ou par
Google, sans autre porte. Deux conséquences à garder en tête.

**Au tout premier lancement, le réseau est indispensable.** Une fois connecté,
Firebase conserve la session et l'application se relance et fonctionne hors
ligne sans problème — mais quelqu'un qui installe Scornade dans un endroit sans
réseau ne pourra pas s'en servir. C'est le prix d'un compte obligatoire.

**Prévois un compte de test pour la revue Apple.** Les relecteurs refusent
régulièrement les applications dont ils ne peuvent pas franchir l'écran de
connexion. Renseigne des identifiants de démonstration dans App Store Connect,
rubrique « Informations de connexion ».
