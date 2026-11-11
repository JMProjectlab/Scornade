# Scornade

Compteur de points pour **23 jeux de société** — belote, coinche, tarot, Yam's,
mölkky, fléchettes, 421, Papayoo, Phase 10, Les Cinq Rois et les autres. Saisie
en direct, historique, statistiques.

Chaque jeu a son écran de saisie : aux jeux à contrat, on entre la donne et non
le résultat, les points se calculent tout seuls.

## Trois clients, deux implémentations

| Client | Où | État |
|---|---|---|
| **iOS** — SwiftUI, cible iOS 17 | `Scornade/` | Publié sur l'App Store ([fiche](https://apps.apple.com/app/id6802812197)) |
| **Web** — HTML/CSS/JS, sans compilation | `docs/` | En ligne : https://jmprojectlab.github.io/Scornade/ |
| **Android** — Trusted Web Activity | `android/` | Écrit, pas encore publié |

L'application Android n'est pas un troisième portage : c'est le client web
lancé en plein écran par Chrome. Les règles de comptage n'existent donc qu'en
**deux** exemplaires — Swift et JavaScript — et non trois. Voir
[`android/README.md`](android/README.md).

> **Le point de vigilance du dépôt** : `Scornade/Scornade/Models.swift` et
> `docs/assets/engine.js` calculent la même chose deux fois. Une correction
> d'un côté doit être reportée de l'autre — le défaut du Papayoo corrigé le
> 22/08 était présent à l'identique dans les deux.

## Ouvrir le projet

```bash
# iOS — nécessite un Mac et Xcode
open Scornade/Scornade.xcodeproj

# Web — aucun outil, aucune compilation ; un serveur statique suffit
python3 -m http.server -d docs 8000

# Android — Android Studio, ou en ligne de commande avec le SDK Android
cd android && ./gradlew assembleDebug
```

## Tests

Les moteurs de score sont couverts des deux côtés, et ce sont les seuls tests
qui comptent vraiment : tout le reste est de l'affichage.

```bash
node --test tests/engine.test.mjs   # web, sans rien installer
# iOS : cible ScornadeTests dans Xcode
```

## Comptes et synchronisation

Firebase Auth + Firestore, **facultatifs**. Sans configuration, l'application
fonctionne en local : les parties vivent sur l'appareil, sans inscription.
C'est le mode par défaut, pas un repli dégradé.

- Mise en place : [`SETUP-FIREBASE.md`](SETUP-FIREBASE.md)
- Règles d'accès : [`firestore.rules`](firestore.rules) — chaque compte ne voit
  que ses propres documents

Les clés de `docs/assets/firebase-config.js` ne sont pas des secrets : elles
partent dans le navigateur de chaque visiteur. Ce qui protège les données, ce
sont les règles Firestore.

## Publication

- App Store : fait le 22/08/2026.
- Google Play : [`PUBLICATION-PLAY-STORE.md`](PUBLICATION-PLAY-STORE.md).

## Organisation du dépôt

```
Scornade/       Application iOS (SwiftUI, 28 fichiers Swift)
docs/           Site web, publié par GitHub Pages — et source de l'app Android
android/        Enveloppe Android (TWA) + visuels de la fiche Play
tests/          Tests du moteur de score web
firestore.rules Règles d'accès Firestore
```
