/* Régénère tous les visuels dérivés de l'icône de l'application.
 *
 * Source unique : l'icône iOS 1024 px. Elle reste la seule image dessinée à la
 * main du projet — tout le reste en découle, pour que l'App Store, Google Play,
 * le site et l'écran d'accueil ne divergent jamais.
 *
 *   npm install sharp
 *   node android/store/generer-visuels.mjs
 */
import sharp from "sharp";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const SRC = `${RACINE}/Scornade/Scornade/Assets.xcassets/AppIcon.appiconset/scornade_icon_1024.png`;
const WEB = `${RACINE}/docs/assets/icons`;
const RES = `${RACINE}/android/app/src/main/res`;
const STORE = `${RACINE}/android/store`;
const ENCRE = "#1d1d1f";

const plein = (taille, sortie) =>
  sharp(SRC).resize(taille, taille, { kernel: "lanczos3" }).png({ compressionLevel: 9 }).toFile(sortie);

/* L'illustration réduite à 86 % et centrée : les cartes restent dans la zone
   sûre quelle que soit la forme découpée par le lanceur Android, et l'icône
   masquable du web suit la même règle. */
async function encadre(taille, sortie, fond) {
  const interieur = Math.round(taille * 0.86);
  const art = await sharp(SRC).resize(interieur, interieur, { kernel: "lanczos3" }).toBuffer();
  const marge = Math.round((taille - interieur) / 2);
  await sharp({ create: { width: taille, height: taille, channels: 4, background: fond } })
    .composite([{ input: art, top: marge, left: marge }])
    .png({ compressionLevel: 9 })
    .toFile(sortie);
}

mkdirSync(WEB, { recursive: true });
await plein(192, `${WEB}/icon-192.png`);
await plein(512, `${WEB}/icon-512.png`);
await plein(180, `${WEB}/apple-touch-icon-180.png`);
await plein(512, `${WEB}/icon-play-512.png`);
await encadre(512, `${WEB}/icon-maskable-512.png`, ENCRE);

/* Android : icône héritée (carrée, avant API 26) et premier plan adaptatif
   (canevas de 108 dp, fond transparent — le fond est une couleur). */
for (const [densite, echelle] of Object.entries({ mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 })) {
  const dossier = `${RES}/mipmap-${densite}`;
  mkdirSync(dossier, { recursive: true });
  await plein(Math.round(48 * echelle), `${dossier}/ic_launcher.png`);
  await encadre(Math.round(108 * echelle), `${dossier}/ic_launcher_foreground.png`, { r: 0, g: 0, b: 0, alpha: 0 });
}

/* Image de présentation Google Play. Le fond du bandeau est l'encre de
   l'icône : la découpe carrée de l'illustration devient invisible. */
const L = 1024, H = 500, ART = 260;
const art = await sharp(SRC).resize(ART, ART, { kernel: "lanczos3" }).toBuffer();
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${L}" height="${H}">
  <rect width="${L}" height="${H}" fill="${ENCRE}"/>
  <text x="485" y="228" font-family="Liberation Sans, Arial, sans-serif" font-size="78" font-weight="700" fill="#f5f5f7">Scornade</text>
  <text x="488" y="284" font-family="Liberation Sans, Arial, sans-serif" font-size="28" fill="#a1a1a6">Compteur de points, 23 jeux</text>
  <text x="488" y="326" font-family="Liberation Sans, Arial, sans-serif" font-size="28" fill="#a1a1a6">Belote, tarot, Yam's, mölkky…</text>
</svg>`;
mkdirSync(STORE, { recursive: true });
await sharp(Buffer.from(svg))
  .composite([{ input: art, top: Math.round((H - ART) / 2), left: 165 }])
  .png({ compressionLevel: 9 })
  .toFile(`${STORE}/feature-graphic-1024x500.png`);

console.log("Visuels régénérés.");
