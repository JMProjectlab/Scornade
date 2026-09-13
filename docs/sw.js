/* Service worker de Scornade.
 *
 * Il sert deux buts, et un seul compte vraiment : rendre l'application
 * utilisable **sans réseau**. Une partie se compte à une table, souvent dans
 * une cuisine ou un jardin où la 4G ne passe pas — et les parties vivent de
 * toute façon dans le navigateur, pas sur un serveur.
 *
 * Le second but est la publication sur Google Play : l'app Android n'est pas
 * un portage, c'est ce site lancé en plein écran par Chrome (Trusted Web
 * Activity, voir `android/`). Sans ce fichier, l'app afficherait la page
 * « pas de connexion » de Chrome dès que le réseau tombe.
 *
 * Stratégies, une par nature de requête :
 *   - navigation      → réseau d'abord, cache en repli (on voit vite une mise
 *                       en ligne, on démarre quand même hors ligne) ;
 *   - ressources du   → cache d'abord, rafraîchi en arrière-plan : le
 *     site               démarrage ne dépend jamais du réseau, et la version
 *                       suivante est prise au lancement d'après ;
 *   - tout le reste   → laissé passer. Le SDK Firebase (gstatic) et Firestore
 *                       ne sont pas interceptés : leur cache est leur affaire,
 *                       et un jeton d'authentification n'a rien à faire ici.
 *
 * Changer un fichier de `SHELL` sans changer `VERSION` ne sert à rien : c'est
 * `VERSION` qui purge l'ancien cache.
 */

const VERSION = "scornade-v1";
const SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./assets/app.css",
  "./assets/store.js",
  "./assets/ui.js",
  "./assets/data.js",
  "./assets/engine.js",
  "./assets/charts.js",
  "./assets/firebase.js",
  "./assets/firebase-config.js",
  "./assets/icons/icon-192.png",
  "./assets/icons/icon-512.png",
  "./assets/icons/icon-maskable-512.png",
  "./politique-de-confidentialite.html",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(VERSION).then(async (cache) => {
      // Un par un, et non `addAll` : un fichier optionnel absent — la
      // configuration Firebase, par exemple — ne doit pas faire échouer
      // l'installation entière et laisser le site sans mode hors ligne.
      await Promise.allSettled(SHELL.map((url) => cache.add(new Request(url, { cache: "reload" }))));
      await self.skipWaiting();
    }),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const noms = await caches.keys();
      await Promise.all(noms.filter((n) => n !== VERSION).map((n) => caches.delete(n)));
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === "navigate") {
    event.respondWith(
      (async () => {
        try {
          const reseau = await fetch(request);
          const cache = await caches.open(VERSION);
          cache.put("./index.html", reseau.clone());
          return reseau;
        } catch {
          return (await caches.match("./index.html")) || (await caches.match("./")) || Response.error();
        }
      })(),
    );
    return;
  }

  event.respondWith(
    (async () => {
      const cache = await caches.open(VERSION);
      const enCache = await cache.match(request);
      const reseau = fetch(request)
        .then((reponse) => {
          if (reponse && reponse.ok) cache.put(request, reponse.clone());
          return reponse;
        })
        .catch(() => null);
      return enCache || (await reseau) || Response.error();
    })(),
  );
});
