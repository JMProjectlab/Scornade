// État de l'application et persistance.
//
// Deux couches, comme côté iOS :
//   • localStorage : lecture instantanée et fonctionnement hors ligne ;
//   • Firestore : synchronisation entre appareils, activée seulement si une
//     configuration Firebase est fournie.
//
// Sans configuration, le site reste pleinement utilisable en local. C'est ce qui
// permet de le déployer et de l'essayer avant d'avoir créé le projet Firebase.

import { HUES, GAMES, gameById as bundledGameById } from "./data.js";
import { isFinished, winnerIndex } from "./engine.js";
import { normalizeCustomGame, toGame } from "./customgames.js";

const KEY_PLAYERS = "sm.players";
const KEY_SESSIONS = "sm.sessions";
const KEY_CUSTOM = "sm.customGames";
const KEY_USER = "sm.user";
const KEY_LANG = "sm.languagePreference";
const KEY_THEME = "sm.theme";

export const state = {
  players: [],
  sessions: [],
  /** Jeux créés par l'utilisateur. Synchronisés comme les joueurs. */
  customGames: [],
  user: null,
  filter: "all",
  /** Renseigné par firebase.js quand la synchronisation est active. */
  sync: null,
  /** Posé par l'amorçage : appelé quand une correction du catalogue arrive. */
  onCatalogChange: null,
};

const listeners = new Set();
export const onChange = (fn) => { listeners.add(fn); return () => listeners.delete(fn); };
function emit() { listeners.forEach((fn) => fn()); }

export const uid = () =>
  (crypto.randomUUID ? crypto.randomUUID() : `id-${Date.now()}-${Math.random().toString(16).slice(2)}`);

// --- Persistance locale ---------------------------------------------------

function readJSON(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function writeJSON(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* quota ou navigation privée */ }
}

export function load() {
  state.players = readJSON(KEY_PLAYERS, []);
  state.sessions = readJSON(KEY_SESSIONS, []);
  state.customGames = readJSON(KEY_CUSTOM, []).map(normalizeCustomGame);
  state.user = readJSON(KEY_USER, null);
}

function persistLocal() {
  writeJSON(KEY_PLAYERS, state.players);
  writeJSON(KEY_SESSIONS, state.sessions);
  writeJSON(KEY_CUSTOM, state.customGames);
}

/** Enregistre, pousse vers Firestore si branché, puis redessine. */
export function commit() {
  persistLocal();
  state.sync?.push(state);
  emit();
}

// --- Préférences ----------------------------------------------------------

export const getLanguage = () => localStorage.getItem(KEY_LANG) || "system";
export const setLanguage = (v) => { localStorage.setItem(KEY_LANG, v); emit(); };
export const getTheme = () => localStorage.getItem(KEY_THEME) || "system";
export function setTheme(v) {
  localStorage.setItem(KEY_THEME, v);
  applyTheme();
  emit();
}
export function applyTheme() {
  const t = getTheme();
  if (t === "system") document.documentElement.removeAttribute("data-theme");
  else document.documentElement.setAttribute("data-theme", t);
}

// --- Compte ---------------------------------------------------------------

export function setUser(user) {
  state.user = user;
  if (user) writeJSON(KEY_USER, user);
  else localStorage.removeItem(KEY_USER);
  emit();
}

export function signOut() {
  state.sync?.stop();
  state.sync = null;
  setUser(null);
}

/** Efface tout, localement et côté serveur. Irréversible. */
export async function deleteEverything() {
  const sync = state.sync;
  state.players = [];
  state.sessions = [];
  state.customGames = [];
  state.sync = null;
  [KEY_PLAYERS, KEY_SESSIONS, KEY_CUSTOM, KEY_USER].forEach((k) => localStorage.removeItem(k));
  state.user = null;
  emit();
  await sync?.deleteAll();
}

// --- Joueurs --------------------------------------------------------------

export function addPlayer(name, email = null) {
  const used = new Set(state.players.map((p) => p.colorIndex));
  let free = 0;
  while (free < HUES.length && used.has(free)) free++;
  if (free >= HUES.length) free = state.players.length % HUES.length;
  state.players.push({ id: uid(), name, colorIndex: free, email });
  commit();
}

export function removePlayer(id) {
  state.players = state.players.filter((p) => p.id !== id);
  commit();
}

export const playerById = (id) => state.players.find((p) => p.id === id);

// --- Jeux personnalisés ---------------------------------------------------

/**
 * Le catalogue effectif : les jeux embarqués, puis ceux que l'utilisateur a
 * créés. Les siens viennent en dernier — le catalogue livré ne bouge pas de
 * place sous ses yeux parce qu'il a inventé un jeu.
 */
export const allGames = () => [...GAMES, ...state.customGames.map(toGame)];

/** Résout un identifiant dans le catalogue complet, jeux personnalisés compris. */
export const gameById = (id) => bundledGameById(id) ?? customAsGame(id);

export const customById = (id) => state.customGames.find((g) => g.id === id);

const customAsGame = (id) => {
  const c = customById(id);
  return c ? toGame(c) : undefined;
};

export function saveCustomGame(raw) {
  const game = normalizeCustomGame(raw);
  const i = state.customGames.findIndex((g) => g.id === game.id);
  if (i >= 0) state.customGames[i] = game;
  else state.customGames.push(game);
  commit();
  return game;
}

/**
 * Supprime un jeu personnalisé. Les parties déjà jouées avec lui restent :
 * elles portent leur propre nom et leur propre symbole, et l'historique comme
 * les statistiques continuent de les afficher.
 */
export function deleteCustomGame(id) {
  state.customGames = state.customGames.filter((g) => g.id !== id);
  commit();
}

// --- Parties --------------------------------------------------------------

export function createSession(game, entrants, target) {
  const session = {
    id: uid(),
    gameId: game.id,
    gameName: game.name,
    // Le symbole est recopié dans la partie : un jeu personnalisé supprimé
    // laisse un historique qui s'affiche encore correctement.
    symbol: game.symbol ?? null,
    date: new Date().toISOString(),
    target,
    higherWins: game.high,
    direction: game.engine === "countdown" ? "countdown" : "accumulate",
    entrants,
    rounds: [],
    manuallyFinished: false,
    seriesWins: null,
    beloteRounds: game.id === "belote" ? [] : null,
    yamsGrid: game.engine === "grid"
      ? entrants.map(() => Array(13).fill(-1))
      : null,
    molkkyMisses: game.engine === "molkky" ? entrants.map(() => 0) : null,
    molkkyOut: game.engine === "molkky" ? entrants.map(() => false) : null,
    roundLimit: game.roundLimit ?? 0,
    phaseRounds: game.engine === "phase" ? [] : null,
  };
  state.sessions.unshift(session);
  commit();
  return session;
}

export const sessionById = (id) => state.sessions.find((s) => s.id === id);
export const activeSession = () => state.sessions.find((s) => !isFinished(s));

export function addRound(session, deltas) {
  session.rounds.push(deltas);
  commit();
}

/**
 * Phase 10 : une manche, ce sont des points de pénalité **et** la liste de ceux
 * qui ont posé leur phase. Les deux vont ensemble — annuler la manche doit
 * rendre sa phase à chacun. Même règle que `Store.addPhaseRound` côté iOS.
 */
export function addPhaseRound(session, deltas, completed) {
  session.phaseRounds ??= [];
  session.phaseRounds.push(session.entrants.map((_, i) => Boolean(completed[i])));
  session.rounds.push(session.entrants.map((_, i) => Number(deltas[i]) || 0));
  commit();
}

export function undoRound(session) {
  if (!session.rounds.length) return;
  const last = session.rounds.length - 1;
  session.rounds.pop();
  // Sans ceci, la donne détaillée survivait à l'annulation et l'historique
  // d'une belote affichait une manche de plus que le score.
  dropStructuredRound(session, last);
  session.manuallyFinished = false;
  commit();
}

export function deleteRound(session, index) {
  if (index < 0 || index >= session.rounds.length) return;
  session.rounds.splice(index, 1);
  dropStructuredRound(session, index);
  session.manuallyFinished = false;
  commit();
}

/**
 * Corrige les points d'une manche déjà jouée.
 *
 * À la belote, `rounds` découle de la donne détaillée. Réécrire les points sans
 * toucher à cette donne les ferait diverger, donc on abandonne le détail de
 * cette manche-là : elle redevient une manche ordinaire, les autres gardent le
 * leur. Même règle que `Store.updateRound` côté iOS.
 */
export function updateRound(session, index, deltas) {
  if (index < 0 || index >= session.rounds.length) return;
  session.rounds[index] = session.entrants.map((_, i) => Number(deltas[i]) || 0);
  dropStructuredRound(session, index, true);
  session.manuallyFinished = false;
  commit();
}

/** `keepPhases` sert à la correction de points : à Phase 10, la phase posée
 *  pendant la manche reste acquise même si son décompte était faux. La
 *  suppression d'une manche, elle, la reprend. */
function dropStructuredRound(session, index, keepPhases = false) {
  if (session.beloteRounds && index < session.beloteRounds.length) {
    session.beloteRounds.splice(index, 1);
  }
  if (!keepPhases && session.phaseRounds && index < session.phaseRounds.length) {
    session.phaseRounds.splice(index, 1);
  }
}

/** Rouvre une partie close à la main. Une partie finie sur l'objectif reste
 *  finie tant que les scores ne redescendent pas — c'est `isFinished` qui
 *  tranche, pas ce drapeau seul. */
export function reopenSession(session) {
  session.manuallyFinished = false;
  commit();
}

export function resetSession(session, keepSeries) {
  if (keepSeries) {
    // Le vainqueur se lit avant la remise à zéro, sinon il n'y en a plus.
    const w = winnerIndex(session);
    if (w !== null) {
      const series = session.seriesWins ?? session.entrants.map(() => 0);
      series[w] += 1;
      session.seriesWins = series;
    }
  } else {
    session.seriesWins = null;
  }
  session.rounds = [];
  if (session.beloteRounds) session.beloteRounds = [];
  // Le tableau vide dit « cette partie suit des phases » ; le mettre à null
  // ferait retomber Phase 10 sur le décompte ordinaire.
  if (session.phaseRounds) session.phaseRounds = [];
  if (session.yamsGrid) session.yamsGrid = session.entrants.map(() => Array(13).fill(-1));
  if (session.molkkyMisses) {
    session.molkkyMisses = session.entrants.map(() => 0);
    session.molkkyOut = session.entrants.map(() => false);
  }
  session.manuallyFinished = false;
  commit();
}

export function finishSession(session) {
  session.manuallyFinished = true;
  commit();
}

export function deleteSession(id) {
  state.sessions = state.sessions.filter((s) => s.id !== id);
  commit();
}

// --- Fusion avec le serveur ----------------------------------------------

/**
 * Applique ce qui vient de Firestore. Comme sur iOS, une absence côté serveur
 * ne supprime rien : elle peut simplement signifier que l'entrée locale n'a pas
 * encore été poussée.
 */
export function mergeRemote({ players, sessions, customGames }) {
  if (players?.length) {
    const byId = new Map(state.players.map((p) => [p.id, p]));
    players.forEach((p) => byId.set(p.id, p));
    state.players = [...byId.values()].sort((a, b) => a.name.localeCompare(b.name));
  }
  if (sessions?.length) {
    const byId = new Map(state.sessions.map((s) => [s.id, s]));
    sessions.forEach((s) => byId.set(s.id, s));
    state.sessions = [...byId.values()].sort((a, b) => (a.date < b.date ? 1 : -1));
  }
  if (customGames?.length) {
    const byId = new Map(state.customGames.map((g) => [g.id, g]));
    customGames.forEach((g) => byId.set(g.id, normalizeCustomGame(g)));
    state.customGames = [...byId.values()].sort((a, b) => a.name.localeCompare(b.name));
  }
  persistLocal();
  emit();
}
