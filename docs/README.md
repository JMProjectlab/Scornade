# Site Scornade

Version web de l'application, à parité de fonctionnalités : catalogue des jeux,
configuration d'une partie, comptage, statistiques. Une colonne sur téléphone,
rail de navigation et écran de score en deux colonnes à partir de 900 px.

## Mettre en ligne

Dépôt GitHub → **Settings → Pages** → Source : `Deploy from a branch`,
branche `main`, dossier **`/docs`**.

Le site est alors publié à l'adresse `https://jmprojectlab.github.io/Scornade/`,
et la politique de confidentialité sur
`https://jmprojectlab.github.io/Scornade/politique-de-confidentialite.html` —
c'est cette adresse-là qu'attend App Store Connect.

> Le chemin suit le **nom du dépôt**. Si le dépôt est renommé, l'URL change
> avec lui (GitHub redirige l'ancienne adresse, mais mieux vaut publier la
> nouvelle). Le domaine autorisé côté Firebase, lui, ne bouge pas : c'est
> `jmprojectlab.github.io`, sans le chemin.

Aucune étape de compilation : ce sont des modules ES chargés directement par le
navigateur.

## Brancher la synchronisation

Sans configuration Firebase, le site tourne en local : les parties vivent dans
le navigateur, sans compte. C'est volontaire — on peut le déployer et s'en
servir avant d'avoir monté le projet Firebase.

Pour activer les comptes et la synchronisation avec l'app iOS :

1. Console Firebase → **Paramètres du projet → Vos applications → Web** →
   enregistrer une application web, copier l'objet de configuration.
2. Le coller dans `assets/firebase-config.js`, à la place des `REMPLACER`.
3. **Authentication → Settings → Domaines autorisés** : ajouter
   `<compte>.github.io`, sinon la fenêtre de connexion sera refusée.

Ces clés ne sont pas des secrets : elles partent dans le navigateur de chaque
visiteur. Ce qui protège les données, ce sont les règles Firestore
(`firestore.rules` à la racine du dépôt), qui n'autorisent chaque compte que sur
ses propres documents.

## Organisation

| Fichier | Rôle |
|---|---|
| `index.html` | Page unique, amorçage des modules |
| `manifest.webmanifest` | Nom, icônes et mode plein écran — installation et app Android |
| `sw.js` | Service worker : cache du site, mode hors ligne |
| `assets/icons/` | Icônes dérivées de l'icône iOS (voir `android/store/`) |
| `assets/data.js` | Les 23 jeux, leurs règles et leurs pictogrammes |
| `assets/engine.js` | Calculs de score — portage de `Models.swift` |
| `assets/charts.js` | Anneau, barres et jauge — SVG écrit à la main |
| `assets/store.js` | État, `localStorage`, fusion avec le serveur |
| `assets/firebase.js` | Connexion et Firestore, chargés à la demande |
| `assets/ui.js` | Rendu des écrans et interactions |
| `assets/app.css` | Charte JMprojectlab, clair et sombre |

## Hors ligne, et sur Android

Le site s'installe sur l'écran d'accueil et **fonctionne sans réseau** dès la
deuxième ouverture : `sw.js` garde le site en cache et `manifest.webmanifest`
le déclare installable. Une partie se compte souvent là où la 4G ne passe pas,
et les parties vivent de toute façon dans le navigateur.

C'est aussi ce qui rend l'application Android possible : elle n'est pas un
portage, c'est ce site lancé en plein écran par Chrome. Une correction poussée
ici arrive sur Android au lancement suivant, sans nouvelle version à soumettre.
Voir [`../android/README.md`](../android/README.md).

> Après un changement dans `assets/`, penser à incrémenter `VERSION` dans
> `sw.js` : c'est cette chaîne qui purge l'ancien cache. Sans elle, un visiteur
> déjà venu garde l'ancienne version un lancement de plus.

## Le point de vigilance

`engine.js` et `Models.swift` calculent la même chose deux fois, dans deux
langages. **Une correction d'un côté doit être reportée de l'autre** : c'est ce
que coûte le choix de deux clients natifs sur une base de données commune.

Les moteurs sont couverts par des tests. Côté web, ils sont versionnés dans
`tests/engine.test.mjs` et se rejouent sans rien installer :

```
node --test tests/engine.test.mjs
```

Côté iOS, la cible `ScornadeTests` couvre les mêmes règles — phases de Phase 10,
nombre de manches des Cinq Rois, fin de partie sur objectif.
