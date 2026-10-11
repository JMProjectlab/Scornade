# Scornade — guide de l'agent

Compteur de scores pour jeux de société. **L'application est en vente sur
l'App Store depuis le 22/08/2026** : une erreur fusionnée ici atteint des
utilisateurs réels.

Ce fichier dit **où ranger quoi** et **ce qu'il ne faut pas casser**.

---

## Où va quoi

| Tu veux… | Ça se passe dans |
|---|---|
| Ajouter un jeu au catalogue | `Scornade/Scornade/GameCatalog.swift` **et** `docs/assets/data.js` |
| Toucher au calcul des scores | `Scornade/Scornade/Models.swift` **et** `docs/assets/engine.js` |
| Écran de comptage d'un jeu | `Scornade/Scornade/<Jeu>ScoringView.swift` |
| Écran web | `docs/assets/ui.js`, graphiques dans `charts.js` |
| Persistance | `Store.swift` côté iOS, `docs/assets/store.js` côté web |
| Firebase | `FirebaseSupport.swift`, `docs/assets/firebase.js`, règles dans `firestore.rules` |
| Couleurs et styles iOS | `Theme.swift` |
| Le site public | `docs/`, publié par GitHub Pages depuis ce dossier |

## Les règles à ne pas casser

### 1. Le moteur de score existe en double

`Models.swift` et `docs/assets/engine.js` calculent la même chose. Une règle
corrigée d'un côté doit l'être de l'autre, sinon l'app et le site donnent deux
scores différents pour la même partie.

Les tests de `tests/engine.test.mjs` disent ce que le côté web est censé faire.
Ils ne couvrent pas le Swift : le côté iOS part non vérifié depuis une session
Linux, et il faut le dire dans la PR.

### 2. Le `payload` Firestore est opaque, et ce n'est pas un oubli

Les documents ne contiennent qu'un champ `payload` : une chaîne JSON. Aucune
requête ne porte sur leur contenu. Firestore ne sert ici que de magasin de
synchronisation clé-valeur.

Conséquence : n'écris jamais une fonctionnalité qui suppose de filtrer, trier ou
agréger côté Firestore. Rien ne le permet sans restructurer d'abord en vrais
champs, ce qui est un chantier, pas une retouche.

### 3. Les règles Firestore refusent tout par défaut

`firestore.rules` n'autorise que `users/{uid}` pour son propriétaire et le
catalogue `games/` en **lecture seule** — aucun client ne peut y écrire, même
authentifié. Les corrections de catalogue passent par la console Firebase.

N'élargis jamais une règle pour faire marcher une fonctionnalité. Si un chemin
est refusé, c'est la fonctionnalité qui est à revoir.

### 4. Le bundle id est définitif

`com.jmprojectlab.scornade` ne peut être ni modifié ni réutilisé depuis la
création de la fiche App Store Connect. Ne propose jamais de le changer.

### 5. Les clés de `firebase-config.js` ne sont pas des secrets

Elles partent dans le navigateur de chaque visiteur. Ce qui protège les données,
ce sont les règles Firestore. Ne les traite pas comme une fuite, et ne les
remplace pas par un mécanisme d'injection qui compliquerait le dépôt pour rien.

En revanche `GoogleService-Info.plist` et les clés `.p8` n'entrent jamais ici.

### 6. Une modification du site est publiée

`.github/workflows/pages.yml` publie `docs/` à chaque fusion. Le site est en
ligne à `jmprojectlab.github.io/Scornade/`. Pas d'étape de validation entre la
fusion et la mise en ligne.

## Vérifier avant de pousser

```bash
node --test tests/engine.test.mjs        # obligatoire si engine.js ou data.js bouge
node --check docs/assets/*.js            # syntaxe
python3 -m http.server -d docs 8000      # essai local du site
```

Au dernier passage : 10 tests, tous verts.

Le Swift ne se compile pas depuis une session Linux. Une PR qui touche au code
iOS doit le signaler et laisser la vérification au Mac, avant publication d'une
nouvelle version.

## Ce que ce dépôt attend encore

Le `README.md` de la racine contient une seule ligne, « # Application ». Les
vrais README sont ceux de `docs/` et de `Scornade/Scornade/`. Si tu touches à la
racine, c'est une occasion de le corriger — mais ne le fais pas en passant au
milieu d'une autre modification.

## Le reste du contexte

Ce qu'il a fallu pour publier, les refus d'examen, la marche à suivre pour la
prochaine publication : second cerveau, dépôt `Brain`. Ce guide ne le duplique
pas.
