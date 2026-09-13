// Jeux personnalisés — définition, validation, mise en forme.
//
// Un jeu personnalisé n'apporte pas de moteur : il en **choisit** un parmi ceux
// que l'application sait déjà tenir. C'est la même règle que pour le catalogue
// corrigé depuis Firestore — « ajouter un jeu à distance supposerait de lui
// fournir un moteur, et un moteur est du code ». Ce qu'on décrit ici, ce sont
// donc les seuls réglages : un nom, un moteur générique, un objectif, un sens
// de victoire.
//
// Le même document est lu par l'app iOS (`CustomGame` dans Models.swift) : les
// clés et les valeurs de `engine` et `symbol` font partie du contrat entre les
// deux clients et ne se renomment pas d'un seul côté.

export const CUSTOM_PREFIX = "custom-";

export const isCustomGame = (id) => typeof id === "string" && id.startsWith(CUSTOM_PREFIX);

/** Les moteurs qu'un jeu personnalisé peut emprunter, et ce qu'ils font. */
export const CUSTOM_ENGINES = [
  ["cumul", "Points cumulés", "On saisit les points de chaque manche, ils s'additionnent."],
  ["countdown", "Compte à rebours", "On part de l'objectif et chaque manche le fait descendre."],
  ["manche", "Manches gagnées", "Une manche gagnée vaut un point ; le premier à l'objectif gagne."],
];

/** Pictogrammes disponibles. Les clés sont communes aux deux clients. */
export const CUSTOM_SYMBOLS = ["star", "heart", "dice", "cards", "flag", "trophy"];

export const CUSTOM_CATEGORIES = ["cartes", "societe", "sport", "des", "perso"];

const MAX_NAME = 40;
const MAX_TARGET = 10000;
const MAX_ROUNDS = 99;
const MAX_RULES = 2000;

export const newCustomGameId = () =>
  CUSTOM_PREFIX + (crypto.randomUUID
    ? crypto.randomUUID()
    : `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`);

/** Un jeu personnalisé vierge, prêt à être édité. */
export function blankCustomGame() {
  return {
    id: newCustomGameId(),
    name: "",
    cat: "perso",
    engine: "cumul",
    symbol: "star",
    team: false,
    target: 500,
    high: true,
    roundLimit: 0,
    rules: "",
    createdAt: new Date().toISOString(),
  };
}

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, Math.round(Number(v) || 0)));
const pick = (v, allowed, fallback) => (allowed.includes(v) ? v : fallback);

/**
 * Ramène une saisie à un jeu valide et stockable.
 *
 * Cette fonction ne refuse rien : elle borne. Ce qui doit bloquer
 * l'enregistrement est dit par `customGameErrors`, qui parle à l'utilisateur.
 */
export function normalizeCustomGame(raw = {}) {
  const engine = pick(raw.engine, CUSTOM_ENGINES.map(([k]) => k), "cumul");
  const target = clamp(raw.target, 0, MAX_TARGET);
  return {
    id: isCustomGame(raw.id) ? raw.id : newCustomGameId(),
    name: String(raw.name ?? "").trim().slice(0, MAX_NAME),
    cat: pick(raw.cat, CUSTOM_CATEGORIES, "perso"),
    engine,
    symbol: pick(raw.symbol, CUSTOM_SYMBOLS, "star"),
    team: Boolean(raw.team),
    // Un compte à rebours sans objectif n'a nulle part où descendre : il
    // commencerait à zéro, donc fini avant d'avoir commencé.
    target: engine === "countdown" && target === 0 ? 500 : target,
    // Descendre à zéro, c'est le plus petit total qui gagne. Le laisser réglable
    // permettrait de décrire une partie que le moteur ne sait pas compter.
    high: engine === "countdown" ? false : Boolean(raw.high),
    roundLimit: clamp(raw.roundLimit, 0, MAX_ROUNDS),
    rules: String(raw.rules ?? "").trim().slice(0, MAX_RULES),
    createdAt: raw.createdAt || new Date().toISOString(),
  };
}

/** Ce qui empêche d'enregistrer, en français et dans l'ordre d'apparition. */
export function customGameErrors(raw = {}, others = []) {
  const g = normalizeCustomGame(raw);
  const errors = [];
  if (!g.name) errors.push("Donnez un nom au jeu.");
  if (others.some((o) => o.id !== g.id && o.name.toLowerCase() === g.name.toLowerCase() && g.name)) {
    errors.push("Vous avez déjà un jeu personnalisé de ce nom.");
  }
  // Sans objectif ni nombre de manches, rien n'arrête la partie : elle ne peut
  // se terminer qu'à la main. C'est un choix acceptable, pas une erreur — mais
  // aux manches gagnées, un objectif de zéro n'a aucun sens.
  if (g.engine === "manche" && g.target === 0 && g.roundLimit === 0) {
    errors.push("Aux manches gagnées, fixez un objectif ou un nombre de manches.");
  }
  return errors;
}

/**
 * Le jeu tel que le reste de l'application l'attend — même forme que les
 * entrées de `GAMES` dans data.js, moteur générique compris.
 *
 * « manches gagnées » n'a pas de moteur à lui : il compte des points cumulés
 * dont chaque manche vaut 1. C'est déjà ainsi que la pétanque et le billard
 * sont tenus dans le catalogue embarqué.
 */
export function toGame(custom) {
  const g = normalizeCustomGame(custom);
  return {
    id: g.id,
    name: g.name,
    cat: g.cat,
    engine: g.engine === "countdown" ? "countdown" : "cumul",
    symbol: g.symbol,
    team: g.team,
    target: g.target,
    high: g.high,
    roundLimit: g.roundLimit,
    rules: g.rules,
    custom: true,
  };
}
