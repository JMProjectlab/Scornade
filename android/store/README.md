# Visuels de la fiche Google Play

| Fichier | Usage | Format imposé |
|---|---|---|
| `feature-graphic-1024x500.png` | Image de présentation, en tête de la fiche | 1024 × 500, PNG ou JPEG, obligatoire |
| `../../docs/assets/icons/icon-play-512.png` | Icône de la fiche | 512 × 512, PNG 32 bits |

Les captures d'écran restent à faire : **2 minimum**, 1080 × 1920 conseillé.
Elles se prennent dans un navigateur en mode appareil mobile, sur
`https://jmprojectlab.github.io/Scornade/` — le site *est* l'application.

## Régénérer

Tout descend de l'icône iOS 1024 px, seule image dessinée à la main du projet :

```bash
npm install sharp
node android/store/generer-visuels.mjs
```

Le script réécrit les icônes du site (`docs/assets/icons/`), celles du module
Android (`app/src/main/res/mipmap-*/`) et l'image de présentation ci-dessus.
