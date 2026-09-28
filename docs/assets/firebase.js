// Synchronisation Firestore — chargée seulement si une configuration existe.
//
// Le SDK est importé dynamiquement : sans `firebase-config.js`, aucun octet
// n'est téléchargé et le site fonctionne en local. La forme des documents est
// exactement celle de l'app iOS — users/{uid}/players|sessions, avec le modèle
// sérialisé en JSON dans un champ `payload` — pour que les deux clients lisent
// et écrivent les mêmes données.

import { mergeRemote, setUser, state } from "./store.js";
import { applyCatalogOverrides, cacheCatalog } from "./data.js";

const SDK = "https://www.gstatic.com/firebasejs/10.12.2";

let mods = null;
let app = null;
let auth = null;
let db = null;
let unsubPlayers = null;
let unsubSessions = null;
const pushed = { players: new Map(), sessions: new Map() };

/** Lit la configuration si elle a été déposée à côté. */
async function loadConfig() {
  try {
    const m = await import("./firebase-config.js");
    const cfg = m.firebaseConfig;
    return cfg && cfg.apiKey && !String(cfg.apiKey).startsWith("REMPLACER") ? cfg : null;
  } catch {
    return null;
  }
}

export async function initFirebase() {
  const config = await loadConfig();
  if (!config) return null;

  const [core, authMod, storeMod] = await Promise.all([
    import(`${SDK}/firebase-app.js`),
    import(`${SDK}/firebase-auth.js`),
    import(`${SDK}/firebase-firestore.js`),
  ]);
  mods = { ...authMod, ...storeMod };
  app = core.initializeApp(config);
  auth = authMod.getAuth(app);
  db = storeMod.getFirestore(app);

  // Le cache local du SDK laisse l'application marcher hors ligne et rejoue les
  // écritures en attente au retour du réseau.
  try {
    await storeMod.enableIndexedDbPersistence(db);
  } catch {
    // Plusieurs onglets ouverts, ou navigateur sans IndexedDB : sans gravité.
  }

  // Le catalogue ne dépend pas du compte : il est commun à tous, et les règles
  // Firestore le laissent lire sans authentification. L'écouter ici, et non
  // depuis la branche connectée, est ce qui permet à un visiteur sans compte de
  // recevoir les corrections.
  watchCatalog();

  authMod.onAuthStateChanged(auth, (user) => {
    if (user) {
      setUser({
        id: user.uid,
        name: user.displayName || "Joueur",
        email: user.email,
        mode: user.providerData[0]?.providerId === "apple.com" ? "apple" : "google",
      });
      startListening(user.uid);
    } else {
      stopListening();
      setUser(null);
    }
  });

  return { signInGoogle, signInApple, signOut: doSignOut, isReady: true };
}

// --- Catalogue des jeux ---------------------------------------------------

let unsubCatalog = null;

/**
 * Écoute les corrections du catalogue.
 *
 * Les documents `games/{id}` redéfinissent, jeu par jeu, un libellé, des règles,
 * une catégorie ou un objectif par défaut. Une collection vide est le cas
 * normal : le catalogue embarqué s'applique alors tel quel.
 *
 * Les règles Firestore interdisent l'écriture depuis le client, donc ce flux
 * est à sens unique — l'application lit, la console corrige. La lecture, elle,
 * est ouverte sans authentification : il n'y a rien à attendre d'une connexion
 * pour une collection identique pour tout le monde.
 */
function watchCatalog() {
  unsubCatalog?.();
  unsubCatalog = mods.onSnapshot(mods.collection(db, "games"), (snap) => {
    const overrides = {};
    snap.forEach((doc) => { overrides[doc.id] = doc.data(); });
    const changed = applyCatalogOverrides(overrides);
    cacheCatalog(overrides);
    // Rien ne sert de tout redessiner si aucun jeu n'a bougé : les écrans de
    // score sont pleins de champs de saisie qui perdraient le focus.
    if (changed > 0) state.onCatalogChange?.();
  }, () => { /* hors ligne : le cache local a déjà été appliqué au démarrage */ });
}

// --- Connexion ------------------------------------------------------------

async function signInGoogle() {
  const provider = new mods.GoogleAuthProvider();
  await mods.signInWithPopup(auth, provider);
}

async function signInApple() {
  const provider = new mods.OAuthProvider("apple.com");
  provider.addScope("email");
  provider.addScope("name");
  await mods.signInWithPopup(auth, provider);
}

async function doSignOut() {
  stopListening();
  await mods.signOut(auth);
}

// --- Écoute et envoi ------------------------------------------------------

function decode(snapshot) {
  const out = [];
  snapshot.forEach((doc) => {
    const raw = doc.data()?.payload;
    if (typeof raw !== "string") return;
    try { out.push(JSON.parse(raw)); } catch { /* document illisible, ignoré */ }
  });
  return out;
}

function startListening(userId) {
  stopListening();
  const root = mods.doc(db, "users", userId);

  unsubPlayers = mods.onSnapshot(mods.collection(root, "players"), (snap) => {
    mergeRemote({ players: decode(snap) });
  });
  unsubSessions = mods.onSnapshot(mods.collection(root, "sessions"), (snap) => {
    mergeRemote({ sessions: decode(snap) });
  });

  state.sync = { push, stop: stopListening, deleteAll };
  push(state);
}

/** Arrête la synchronisation du compte — mais pas l'écoute du catalogue, qui ne
 *  dépend d'aucun compte et survit donc à la déconnexion. */
function stopListening() {
  unsubPlayers?.(); unsubPlayers = null;
  unsubSessions?.(); unsubSessions = null;
}

/** N'écrit que les documents dont le JSON a changé depuis le dernier envoi. */
async function push(current) {
  const user = auth?.currentUser;
  if (!user) return;
  const root = mods.doc(db, "users", user.uid);
  const batch = mods.writeBatch(db);
  let writes = 0;

  const stage = (items, name) => {
    const cache = pushed[name];
    const present = new Set(items.map((i) => i.id));
    for (const item of items) {
      const json = JSON.stringify(item);
      if (cache.get(item.id) === json) continue;
      batch.set(mods.doc(mods.collection(root, name), item.id), {
        payload: json,
        updatedAt: mods.serverTimestamp(),
      });
      cache.set(item.id, json);
      writes++;
    }
    for (const gone of [...cache.keys()].filter((k) => !present.has(k))) {
      batch.delete(mods.doc(mods.collection(root, name), gone));
      cache.delete(gone);
      writes++;
    }
  };

  stage(current.players, "players");
  stage(current.sessions, "sessions");
  if (!writes) return;
  try { await batch.commit(); } catch { /* Firestore rejouera au retour du réseau */ }
}

/** Supprime les documents puis le compte lui-même. */
async function deleteAll() {
  const user = auth?.currentUser;
  if (!user) return;
  const root = mods.doc(db, "users", user.uid);
  const batch = mods.writeBatch(db);
  for (const name of ["players", "sessions"]) {
    const snap = await mods.getDocs(mods.collection(root, name));
    snap.forEach((d) => batch.delete(d.ref));
    pushed[name].clear();
  }
  try {
    await batch.commit();
    await mods.deleteUser(user);
  } catch {
    // Firebase peut exiger une reconnexion récente avant de supprimer un compte.
  }
}
