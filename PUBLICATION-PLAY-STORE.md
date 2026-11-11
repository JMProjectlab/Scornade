# Publier Scornade sur Google Play

Marche à suivre pour la **v1.0 Android, gratuite et sans achat intégré**.
L'application est une *Trusted Web Activity* : voir [`android/README.md`](android/README.md)
pour ce que ça implique techniquement.

Ce document suit l'ordre réel des blocages, pas l'ordre du formulaire.

> **L'ordre qui compte, en une ligne.** Compte → compiler → fiche → AAB signé
> déposé en test fermé → les douze testeurs s'inscrivent → **là** les quatorze
> jours démarrent → production. Le dépôt du premier AAB est donc sur le chemin
> critique, avant l'attente et non pendant : chaque jour qui le précède
> s'ajoute au total.

---

## Ce qui est déjà là

| Élément | État |
|---|---|
| Client web à parité (23 jeux) | ✅ en ligne |
| Mode hors ligne (service worker, manifeste) | ✅ ajouté |
| Icônes, écran de démarrage, module Android | ✅ écrits, **jamais compilés** |
| Politique de confidentialité en ligne | ✅ `https://jmprojectlab.github.io/Scornade/politique-de-confidentialite.html` |
| Compte développeur Google Play | ❌ |
| `assetlinks.json` à la racine du domaine | ❌ |
| Clé de signature | ❌ |

---

## A. Compte développeur — à faire en premier

25 $ **une seule fois** (Apple, c'est 99 $ par an : la comparaison s'arrête là,
le reste est plus contraignant chez Google).

1. https://play.google.com/console → créer un compte **personnel**.
2. **Vérification d'identité** : pièce d'identité, et une adresse postale qui
   sera **affichée publiquement** sur la fiche. Compter quelques jours.
3. Renseigner l'adresse e-mail de contact — publique elle aussi.

C'est la seule étape qui ne dépend que d'un délai : la lancer avant d'écrire
quoi que ce soit d'autre.

## B. Les tests fermés obligatoires — la vraie surprise

> Un compte développeur **personnel** créé après le 13 novembre 2023 doit
> faire tester l'application par **au moins 12 testeurs, restés inscrits
> 14 jours d'affilée**, avant de pouvoir demander l'accès à la production.

Ce n'est pas une recommandation, c'est une porte fermée : le bouton « produire
une version de production » reste inactif tant que la condition n'est pas
remplie. Concrètement, **deux semaines minimum** entre le premier envoi et la
mise en vente, et douze adresses Google réelles à réunir.

**Le compteur ne démarre pas à la création du compte.** On ne s'inscrit qu'à un
test fermé qui existe, c'est-à-dire qui porte déjà une version déposée. Il faut
donc avoir compilé (**C**), créé la fiche (**D**) et déposé un AAB signé
(**E**) avant que le premier des quatorze jours puisse commencer. Recruter les
douze personnes se fait dès maintenant ; leur inscription, elle, attend la
version.

- Réunir les douze adresses **maintenant**, pas à la fin — les prévenir tôt
  coûte zéro et évite de chercher des volontaires le jour du dépôt.
- Les inscrire dans *Test et publication → Tests → Tests fermés → Testeurs*.
- Un testeur qui se désinscrit avant les 14 jours fait repartir le compteur.
- Depuis 2026, Google vérifie en plus que les testeurs ont **réellement utilisé**
  l'application : les inscrire ne suffit pas, il faut leur demander de l'ouvrir.

Une porte de sortie existe, et elle mérite d'être pesée avant de créer le
compte : un compte **organisation**, adossé à une entité légale, est exempté de
cette obligation — et son adresse publique est celle de la structure, pas la
sienne. Il suppose en revanche une entité déclarée et un numéro DUNS. Comme la
question d'une micro-entreprise se pose de toute façon pour encaisser (voir
`À vérifier avant d'encaisser` côté App Store), autant trancher une seule fois.

Rien d'équivalent chez Apple, où TestFlight est facultatif. C'est le pendant
Google du refus « Guideline 2.1 » : administratif, pas technique.

## C. Créer l'application dans la console

- Nom : `Scornade`
- Langue par défaut : **français (France)**
- Type : **Application**, **Gratuite** — le passage gratuit → payant est
  impossible ensuite (l'inverse est permis).
- Nom de paquet : `com.jmprojectlab.scornade`, **définitif**. Même règle que le
  bundle id iOS : ni modifiable, ni réutilisable après publication.

## C bis. Viser la bonne API — non négociable

À partir du **31 août 2026**, toute nouvelle application soumise à Google Play
doit viser **l'API 36** (Android 16). Le premier envoi tombera nécessairement
après cette date : les quatorze jours de test fermé l'imposent.

Le module est déjà en `targetSdk 36` et `compileSdk 36`, avec l'AGP qui va avec
(8.10 minimum le supporte ; 8.9 plafonne à l'API 35). Rien à faire, donc — mais
ça n'allait pas de soi, et une soumission en API 35 serait refusée.

## D. Construire l'AAB signé

Créer la clé, puis produire le paquet — détail dans
[`android/README.md`](android/README.md) :

```bash
cd android
./gradlew bundleRelease
# app/build/outputs/bundle/release/app-release.aab
```

Laisser **Play App Signing** activé (il l'est par défaut, et il est obligatoire
pour toute nouvelle application). La clé créée localement n'est plus que la clé
*d'envoi* ; c'est Google qui détient la clé de signature finale.

## E. Publier `assetlinks.json` — sinon la barre d'adresse reste

À faire **après** le premier envoi, parce que l'empreinte à déclarer est celle
de la clé de signature générée par Google, visible seulement une fois un AAB
déposé.

1. Play Console → *Test et publication* → *Intégrité de l'application* →
   copier l'empreinte **SHA-256** du certificat de signature de l'application.
2. La coller dans `android/assetlinks.json`.
3. Publier ce fichier à `https://jmprojectlab.github.io/.well-known/assetlinks.json` —
   voir [`android/README.md`](android/README.md#le-point-bloquant--digital-asset-links)
   pour les deux façons de servir la racine du domaine.
4. Vérifier : `curl https://jmprojectlab.github.io/.well-known/assetlinks.json`

Tant que cette étape n'est pas faite, l'application fonctionne mais s'affiche
avec la barre d'adresse de Chrome. **Le vérifier sur un appareil réel avant la
version de production**, pas après.

## F. La fiche

### Titre — 30 caractères

```
Scornade — compteur de points
```

29 caractères.

### Description courte — 80 caractères

```
Fini les feuilles de score : belote, tarot, Yam's, mölkky et 19 autres jeux.
```

76 caractères. Elle reprend le sous-titre de la fiche App Store et y ajoute le
nombre, parce que Google n'a pas de champ « mots-clés » : c'est le texte qui
porte le référencement.

### Description complète — 4 000 caractères

```
Plus de feuille de score griffonnée au dos d'une enveloppe, plus de calcul
mental à la fin de la manche. Scornade compte les points de vos parties, dans
les règles de chaque jeu.

Plus de 20 jeux
Belote, coinche, tarot, Yam's, mölkky, fléchettes, 421, Papayoo, Phase 10,
Les Cinq Rois, Dékal et bien d'autres. Chaque jeu a son écran de saisie : aux
jeux à contrat, vous entrez la donne et non le résultat — les points se
calculent tout seuls.

Une saisie faite pour la table
Les totaux se mettent à jour à chaque manche et le vainqueur est annoncé dès
que l'objectif est atteint. Une manche saisie de travers se corrige sans tout
reprendre.

Vos parties, gardées
L'historique conserve chaque partie terminée. Les statistiques montrent qui
gagne, à quel jeu, et depuis quand.

Avec ou sans compte
Scornade fonctionne immédiatement, sans inscription : tout reste sur votre
appareil. Créez un compte seulement si vous souhaitez retrouver vos parties sur
vos autres appareils — y compris sur iPhone, où l'application existe aussi.

Sans réseau
Une fois lancée, l'application se passe de connexion. Une partie se compte
souvent là où le réseau ne passe pas.
```

Deux différences avec le texte App Store, volontaires :

1. Les intitulés de section ne sont **pas en capitales** : la politique de
   Google décourage les majuscules décoratives dans les métadonnées.
2. La liste de jeux est plus longue, parce qu'elle remplace le champ
   « mots-clés » qui n'existe pas ici. **Ne pas y mettre un jeu absent du
   catalogue** — c'est vérifiable en trente secondes par un relecteur, et c'est
   exactement le genre de détail qui a coûté deux refus côté Apple.

### Éléments graphiques

| Élément | Format | Où |
|---|---|---|
| Icône | 512 × 512 PNG | `docs/assets/icons/icon-play-512.png` |
| Image de présentation | 1024 × 500 PNG | `android/store/feature-graphic-1024x500.png` |
| Captures téléphone | 2 minimum, 1080 × 1920 recommandé | à faire |

Les captures se prennent au choix sur un téléphone Android ou dans un
navigateur en mode appareil mobile (le site *est* l'application) — ce dernier
point est un gain net par rapport à iOS, où il a fallu le simulateur Xcode.

## G. Les questionnaires

| Formulaire | Réponse attendue |
|---|---|
| Classification du contenu | Utilitaire / jeu de société, aucun contenu sensible → tout public |
| Sécurité des données | Adresse e-mail et données de partie **si un compte est créé**, chiffrées en transit, suppression possible. Sans compte : aucune collecte |
| Public cible | Adultes et adolescents ; **ne pas** cocher « conçue pour les enfants », ce qui déclencherait les règles Families |
| Publicités | Non |
| Accès à l'application | Aucun identifiant nécessaire pour tester : le bouton « Continuer sans compte » suffit — le préciser explicitement, sinon le relecteur bloque |

La dernière ligne est le pendant Google de l'échange « Information Needed » qui
a coûté une resoumission côté Apple. Le dire d'avance évite l'aller-retour.

## H. Envoyer

Tests fermés → 14 jours et 12 testeurs → demande d'accès à la production →
version de production. L'examen prend de quelques heures à quelques jours ;
le premier envoi d'un compte neuf est plus long que les suivants.

---

## Ce qui change par rapport à l'App Store

| | Apple | Google |
|---|---|---|
| Coût | 99 $ / an | 25 $ une fois |
| Verrou principal | L'examen, humain et tatillon | Les **12 testeurs pendant 14 jours** |
| Signature | Certificats gérés par Xcode | Play App Signing : Google détient la clé |
| Format | `.ipa` via Xcode | `.aab` via Gradle |
| Mise à jour du contenu | Nouvelle version à faire examiner | **Aucune** : le site est mis à jour, l'app suit |

La dernière ligne est la vraie différence de nature. Côté Android, une
correction de règle de comptage part en ligne le jour même ; côté iOS, elle
attend un examen. C'est le bénéfice direct du choix de la TWA.

## Après la publication

- Le `versionCode` doit **augmenter** à chaque envoi, sans exception.
- Une correction du site ne demande aucun envoi.
- L'achat intégré, s'il vient un jour, se fait par la *Digital Goods API* dans
  la TWA — et suppose un compte de paiement Google Merchant, à traiter en même
  temps que le contrat Paid Applications d'Apple plutôt que séparément.
