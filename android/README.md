# Scornade pour Android

L'application Android n'est **pas un portage** : c'est le site
`https://jmprojectlab.github.io/Scornade/` lancé en plein écran par Chrome, au
moyen d'une *Trusted Web Activity* (TWA). Le module ci-dessous ne contient
aucune ligne de code applicatif — que des ressources, un manifeste et une
dépendance.

## Pourquoi ce choix

Les règles de comptage des 23 jeux existent déjà deux fois : en Swift
(`Scornade/Scornade/Models.swift`) et en JavaScript (`docs/assets/engine.js`).
Un troisième client natif en ferait une **troisième** copie à corriger à chaque
bug — le défaut du Papayoo corrigé le 22/08 aurait demandé trois correctifs au
lieu de deux.

La TWA ne duplique rien : elle affiche le client web, qui est déjà à parité de
fonctionnalités. Une correction poussée dans `docs/` arrive sur Android au
lancement suivant, **sans nouvelle version à soumettre**.

Ce que ça coûte en échange :

- Il faut Chrome (ou un navigateur compatible TWA) installé sur l'appareil ;
  sinon l'app se replie sur un onglet personnalisé, habillé d'une barre.
- Le hors-ligne dépend du service worker du site (`docs/sw.js`), pas d'un
  paquet embarqué : le tout premier lancement demande du réseau.
- Pas d'API native. Un achat intégré Google Play, le jour venu, demanderait
  d'ajouter la facturation côté application — c'est faisable dans une TWA
  (`Digital Goods API`), mais ce n'est pas fait ici.

## Compiler

Il faut **Android Studio** (ou le SDK Android en ligne de commande) et un
**JDK 17**. Aucune dépendance n'est vendorisée : AGP et
`androidbrowserhelper` sont téléchargés depuis `google()` et `mavenCentral()`.

```bash
cd android
./gradlew assembleDebug      # APK de test  → app/build/outputs/apk/debug/
./gradlew bundleRelease      # AAB pour Play → app/build/outputs/bundle/release/
```

Google Play n'accepte que l'**AAB** pour une nouvelle application ; l'APK ne
sert qu'à installer sur son propre téléphone.

> **Ce module n'a jamais été compilé.** Il a été écrit sans SDK Android
> disponible : le réseau de la machine ne donne accès ni à `dl.google.com` ni
> au dépôt Maven de Google. La première ouverture dans Android Studio est donc
> un vrai test — et c'est aussi elle qui proposera, le cas échéant, de mettre à
> jour le couple AGP / Gradle déclaré ici (8.10.1 et 8.11.1).

## Signer

La clé de signature ne se trouve pas dans le dépôt, et ne doit jamais y entrer :
**la perdre, c'est perdre le droit de mettre l'application à jour** — Google ne
la régénère pas, il faudrait republier sous un autre nom de paquet.

```bash
cd android
keytool -genkeypair -v -keystore scornade-upload.jks -alias scornade \
        -keyalg RSA -keysize 2048 -validity 10000
cp keystore.properties.exemple keystore.properties   # puis renseigner les mots de passe
```

`keystore.properties` et `*.jks` sont exclus par le `.gitignore` de ce dossier.
Sauvegarder les deux ailleurs qu'ici — un gestionnaire de mots de passe fait
l'affaire.

## Le point bloquant : Digital Asset Links

C'est **la** difficulté de ce projet, l'équivalent Android des refus rencontrés
à l'App Store. Sans elle, l'application s'ouvre quand même, mais avec la barre
d'adresse de Chrome en haut de l'écran — ce qui la fait ressembler à ce qu'elle
est, un site, et non à une application.

Il faut une déclaration **des deux côtés** :

| Côté | Où | État |
|---|---|---|
| Application | `app/src/main/res/values/strings.xml`, chaîne `asset_statements` | ✅ fait |
| Site | `https://jmprojectlab.github.io/.well-known/assetlinks.json` | ❌ à publier |

Le modèle à publier est `assetlinks.json`, dans ce dossier. Deux choses à savoir
avant de le déposer.

### 1. L'empreinte à mettre dedans est celle de Google, pas la vôtre

Avec Play App Signing — activé par défaut, et obligatoire pour toute nouvelle
application — Google **resigne** l'AAB avec sa propre clé. L'empreinte à
déclarer est donc celle affichée dans la console, pas celle de la clé
d'envoi :

> Play Console → *Test et publication* → *Intégrité de l'application* →
> *Certificat de la clé de signature de l'application* → SHA-256

Y mettre l'empreinte de la clé d'envoi (`keytool -list -v -keystore
scornade-upload.jks`) est l'erreur classique : la vérification échoue en
silence, et la barre d'adresse reste.

### 2. Le fichier doit être à la racine du **domaine**, pas du site

Le site vit dans un sous-chemin, `jmprojectlab.github.io/Scornade/`. Chrome, lui,
ne lit `assetlinks.json` qu'à la racine de l'origine :
`https://jmprojectlab.github.io/.well-known/assetlinks.json`. Publier le fichier
dans `docs/` ne sert donc à rien.

Deux façons de s'en sortir :

- **Créer le dépôt `JMProjectlab/jmprojectlab.github.io`** (public, Pages
  activé). Il sert la racine du domaine, et donc `.well-known/`. C'est le chemin
  le plus court, et il ne change rien à l'adresse actuelle du site. S'il est
  publié par « Deploy from a branch », il lui faut un fichier `.nojekyll` vide :
  sans lui, Jekyll ignore les dossiers commençant par un point et le fichier
  n'est jamais servi.
- **Attacher un nom de domaine** au site Scornade (`CNAME` dans `docs/`). La
  racine du domaine devient alors `docs/`, et `docs/.well-known/assetlinks.json`
  suffit. Ici, rien à ajouter : le site est publié par `.github/workflows/pages.yml`,
  qui téléverse `docs/` tel quel, sans passer par Jekyll.

Vérifier ensuite, avant de soumettre quoi que ce soit :

```bash
curl https://jmprojectlab.github.io/.well-known/assetlinks.json
```

Et une fois l'app installée, la vérification côté appareil :

```bash
adb shell pm get-app-links com.jmprojectlab.scornade
```

## Ce qu'il faut toucher, et quand

| Changement | Fichier |
|---|---|
| Nouvelle adresse du site | `res/values/strings.xml` → `launch_url`, `host_name`, `asset_statements`, et le `pathPrefix` du manifeste |
| Nouvelle version publiée | `app/build.gradle.kts` → `versionCode` (+1, obligatoire) et `versionName` |
| Couleurs des barres système | `res/values/colors.xml` et `res/values-night/colors.xml` |
| Icône | régénérée depuis `Scornade/Scornade/Assets.xcassets/AppIcon.appiconset/scornade_icon_1024.png` |

Une correction du **site** ne demande aucune nouvelle version Android : elle est
en ligne au lancement suivant.

## Suite

La marche à suivre complète pour la mise en vente — compte développeur, fiche,
tests fermés obligatoires, questionnaires — est dans
[`../PUBLICATION-PLAY-STORE.md`](../PUBLICATION-PLAY-STORE.md).
