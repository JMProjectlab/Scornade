// Moteurs de score — portage direct de Models.swift.
// Toute correction faite ici doit l'être aussi côté Swift, et réciproquement :
// c'est le prix d'avoir deux clients natifs sur une base de données commune.

/** Total d'un participant. En compte à rebours, on part de l'objectif. */
export function total(session, i) {
  const sum = session.rounds.reduce((acc, r) => acc + (r[i] ?? 0), 0);
  return session.direction === "countdown" ? Math.max(0, session.target - sum) : sum;
}

/** Phase 10 : la phase en cours d'un joueur, de 1 à 10, puis 11 une fois les
 *  dix franchies. */
export function phaseOf(session, i) {
  if (!session.phaseRounds) return 1;
  const done = session.phaseRounds.reduce((acc, r) => acc + (r[i] ? 1 : 0), 0);
  return Math.min(done + 1, 11);
}

/** Phase 10 : les joueurs qui ont posé leur dixième phase. */
export function phaseFinishers(session) {
  if (!session.phaseRounds) return [];
  return session.entrants.map((_, i) => i).filter((i) => phaseOf(session, i) > 10);
}

export function reachedEnd(session) {
  const idx = session.entrants.map((_, i) => i);
  // Phase 10 : ce sont les phases qui terminent la partie, pas les points, qui
  // ne sont que des pénalités et n'ont pas d'objectif à atteindre.
  if (session.phaseRounds) return phaseFinishers(session).length > 0;
  // Les Cinq Rois se jouent en onze manches, ni plus ni moins.
  if (session.roundLimit > 0 && session.rounds.length >= session.roundLimit) return true;
  if (session.direction === "countdown") return idx.some((i) => total(session, i) <= 0);
  return session.target > 0 && idx.some((i) => total(session, i) >= session.target);
}

export const isFinished = (s) => s.manuallyFinished || reachedEnd(s);

export function winnerIndex(session) {
  if (!isFinished(session) || !session.entrants.length) return null;
  const totals = session.entrants.map((_, i) => total(session, i));
  // Phase 10 : avoir fini les dix phases prime sur le total ; si deux joueurs
  // finissent dans la même manche, le plus petit score départage.
  const finishers = phaseFinishers(session);
  if (finishers.length) {
    return finishers.reduce((best, i) => (totals[i] < totals[best] ? i : best), finishers[0]);
  }
  if (session.direction === "countdown") return totals.indexOf(Math.min(...totals));
  return session.higherWins ? totals.indexOf(Math.max(...totals)) : totals.indexOf(Math.min(...totals));
}

// --- Belote : BeloteRound.deltas() ---------------------------------------

/** Litige : le preneur fait exactement la moitié des 162 points. */
export const BELOTE_LITIGE = 81;

/** 81 partout : le contrat n'est ni tenu ni chuté. */
export function beloteIsLitige(r) {
  return (r.capotTeam === null || r.capotTeam === undefined)
    && r.cardPoints[r.takerTeam] === BELOTE_LITIGE;
}

/**
 * Points restés en jeu après la dernière donne, à encaisser par le camp qui
 * remportera la suivante.
 *
 * Seule la dernière donne compte : une donne tranchée solde l'ardoise. Les
 * litiges, eux, s'enchaînent — deux de suite mettent 162 points en jeu.
 */
export function belotePending(rounds) {
  const last = rounds?.[rounds.length - 1];
  if (!last || !beloteIsLitige(last)) return 0;
  return (last.pending ?? 0) + BELOTE_LITIGE;
}

export function beloteContractMade(r) {
  if (r.capotTeam !== null && r.capotTeam !== undefined) return true;
  return r.cardPoints[r.takerTeam] >= 82;
}

/** Issue d'une donne, pour l'affichage : "fait", "litige" ou "chute". */
export function beloteOutcome(r) {
  if (beloteIsLitige(r)) return "litige";
  return beloteContractMade(r) ? "fait" : "chute";
}

export function beloteDeltas(r) {
  const s = [0, 0];
  const t = r.takerTeam, d = 1 - t;
  // Points mis en jeu par le ou les litiges qui précèdent cette donne.
  const pending = r.pending ?? 0;
  if (r.capotTeam !== null && r.capotTeam !== undefined) {
    const c = r.capotTeam, o = 1 - c;
    s[c] = 252 + (r.belote[c] ? 20 : 0) + pending;
    s[o] = r.belote[o] ? 20 : 0;
    return s;
  }
  if (beloteIsLitige(r)) {
    // 81 partout : la défense marque ses 81 points, ceux du preneur sont remis
    // en jeu pour la donne suivante — avec ceux déjà en attente, le cas échéant.
    s[d] = BELOTE_LITIGE + (r.belote[d] ? 20 : 0);
    s[t] = r.belote[t] ? 20 : 0;
    return s;
  }
  if (r.cardPoints[t] >= 82) {
    for (let i = 0; i < 2; i++) s[i] = r.cardPoints[i] + (r.belote[i] ? 20 : 0);
    s[t] += pending;
  } else {
    // Le preneur est dedans : les 162 points partent à la défense.
    s[d] = 162 + (r.belote[d] ? 20 : 0) + pending;
    s[t] = r.belote[t] ? 20 : 0;
  }
  return s;
}

// --- Yam's ----------------------------------------------------------------

export const YAMS_CATEGORIES = [
  ["As (1)", null], ["Deux (2)", null], ["Trois (3)", null], ["Quatre (4)", null],
  ["Cinq (5)", null], ["Six (6)", null], ["Brelan", null], ["Carré", null],
  ["Full", 25], ["Petite suite", 30], ["Grande suite", 40], ["Yam's", 50], ["Chance", null],
];

export const yamsCell = (s, p, c) => s.yamsGrid?.[p]?.[c] ?? -1;

export function yamsUpper(s, p) {
  let t = 0;
  for (let c = 0; c < 6; c++) t += Math.max(0, yamsCell(s, p, c));
  return t;
}
export function yamsLower(s, p) {
  let t = 0;
  for (let c = 6; c < 13; c++) t += Math.max(0, yamsCell(s, p, c));
  return t;
}
export const yamsBonus = (s, p) => (yamsUpper(s, p) >= 63 ? 35 : 0);
export const yamsTotal = (s, p) => yamsUpper(s, p) + yamsBonus(s, p) + yamsLower(s, p);

export function yamsAllFilled(s) {
  if (!s.entrants.length) return false;
  return s.entrants.every((_, p) =>
    Array.from({ length: 13 }, (_, c) => c).every((c) => yamsCell(s, p, c) >= 0));
}

// --- Fléchettes -----------------------------------------------------------

/** Renvoie le delta à enregistrer et le message éventuel. */
export function dartsThrow(session, playerIndex, score) {
  if (score < 0 || score > 180) return null;
  const remaining = total(session, playerIndex);
  const next = remaining - score;
  // Impossible de finir sur 1 : une volée qui dépasse ou laisse 1 est annulée.
  if (next < 0 || next === 1) {
    return { delta: 0, note: "Bust ! La volée ne compte pas.", advance: true };
  }
  return { delta: score, note: null, advance: next > 0 };
}

// --- Mölkky ---------------------------------------------------------------

export const PAYOO_ROUND_TOTAL = 250;

export function molkkyThrow(session, playerIndex, score) {
  if (score < 0 || score > 12) return null;
  const current = total(session, playerIndex);
  const next = current + score;
  // Dépasser 50 fait retomber à 25.
  if (next > 50) return { delta: 25 - current, note: "Raté ! Retour à 25 points.", advance: true };
  return { delta: score, note: null, advance: next !== 50 };
}

// --- Phase 10 -------------------------------------------------------------

export const PHASE10_PHASES = [
  "deux brelans",
  "un brelan et une suite de 4",
  "un carré et une suite de 4",
  "une suite de 7",
  "une suite de 8",
  "une suite de 9",
  "deux carrés",
  "sept cartes d'une même couleur",
  "cinq cartes de même valeur et une paire",
  "cinq cartes de même valeur et un brelan",
];
