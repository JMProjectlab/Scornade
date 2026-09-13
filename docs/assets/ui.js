// Rendu et interactions.
//
// Un seul point de rendu : l'état change, on redessine l'écran courant. C'est
// assez rapide à cette échelle, et ça évite d'avoir à synchroniser à la main
// une douzaine de fragments de vue.

import { CATEGORIES, HUES, glyph } from "./data.js";
import {
  CUSTOM_ENGINES, CUSTOM_SYMBOLS, blankCustomGame, customGameErrors, isCustomGame,
} from "./customgames.js";
import * as C from "./charts.js";
import * as E from "./engine.js";
import * as S from "./store.js";

const esc = (v) => String(v).replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

/** État de navigation, hors données. */
let view = { screen: "home" };
let scratch = {};          // saisies en cours, jamais persistées
let auth = null;           // API renvoyée par initFirebase(), ou null

export function setAuth(api) { auth = api; }
export const requiresSignIn = () => Boolean(auth) && !S.state.user;

export function go(next) {
  view = next;
  scratch = {};
  render();
  document.querySelector(".content")?.scrollTo({ top: 0 });
}

// --- fragments partagés ---------------------------------------------------

function avatar(name, colorIndex, small = false) {
  const hue = HUES[colorIndex % HUES.length];
  const initials = String(name).trim().slice(0, 2).toUpperCase();
  return `<span class="avatar${small ? " sm" : ""}" style="background:${hue}22;color:${hue}"
    aria-hidden="true">${esc(initials)}</span>`;
}

function toast(message) {
  document.querySelector(".toast")?.remove();
  const el = document.createElement("div");
  el.className = "toast";
  el.setAttribute("role", "status");
  el.textContent = message;
  document.body.append(el);
  setTimeout(() => el.remove(), 2400);
}

/** Feuille de texte simple — les règles, notamment. Le texte est échappé, puis
 *  ses paragraphes sont rendus tels qu'ils ont été écrits : depuis qu'elles
 *  expliquent vraiment comment on joue, les règles font plusieurs lignes. */
function openSheet(title, body) {
  const html = String(body).split("\n").map((line) => {
    const t = line.trim();
    if (t === "") return "";
    return `<p class="${t.startsWith("•") ? "li" : ""}">${esc(t)}</p>`;
  }).join("");
  openSheetHTML(title, html);
}

/** Même feuille, mais dont le contenu est du balisage déjà construit — pour
 *  l'éditeur de manche, qui a besoin de champs de saisie. */
function openSheetHTML(title, bodyHtml) {
  const dlg = document.getElementById("sheet");
  dlg.innerHTML = `<div class="sheet-head"><h2>${esc(title)}</h2>
      <button class="ghost" data-act="close-sheet">Fermer</button></div>
    <div class="sheet-body">${bodyHtml}</div>`;
  dlg.showModal();
}

/** Corrige les points d'une manche déjà jouée. */
function openRoundEditor(session, index) {
  const round = session.rounds[index] ?? [];
  const fields = session.entrants.map((e, i) =>
    `<label class="row" style="gap:12px">
      <span class="name">${esc(e.name)}</span>
      <input class="round-edit" type="text" inputmode="numeric" data-i="${i}"
        value="${round[i] ?? 0}" aria-label="Points de ${esc(e.name)}"
        style="width:90px;text-align:right"></label>`).join("");

  const warning = session.beloteRounds && index < session.beloteRounds.length
    ? `<p class="hint">Le détail de la donne (contrat, annonces) sera perdu :
       seuls les points corrigés seront conservés.</p>`
    : "";

  openSheetHTML(`Manche ${index + 1}`,
    `${fields}${warning}
     <button class="btn primary" data-act="save-round" data-i="${index}">Enregistrer</button>`);
}

// --- écrans ---------------------------------------------------------------

function screenLogin() {
  return `<div class="login">
    <div class="mark">Sc</div>
    <h1>Scornade</h1>
    <p class="tagline">Comptez. Gagnez. Recommencez.</p>
    <button class="btn" style="background:var(--ink);color:var(--bg)" data-act="sign-apple">
      Se connecter avec Apple</button>
    <div class="sep">ou</div>
    <button class="btn outline" data-act="sign-google">Se connecter avec Google</button>
    <p class="legal">Un compte permet de retrouver vos parties sur vos autres appareils.<br>
      <a href="politique-de-confidentialite.html">Politique de confidentialité</a></p>
  </div>`;
}

function screenHome() {
  const active = S.activeSession();
  const catalog = S.allGames();
  const games = S.state.filter === "all" ? catalog : catalog.filter((g) => g.cat === S.state.filter);

  let html = "";
  if (active) {
    const line = active.entrants.map((e, i) => `${e.name} ${E.total(active, i)}`).join(" · ");
    html += `<button class="active-card" data-act="open-session" data-id="${active.id}">
      <span class="active-top"><span class="tag">EN COURS</span>
        <span class="sub">Manche ${active.rounds.length}</span></span>
      <span class="active-name">${glyph(active.gameId, 20, active.symbol)}${esc(active.gameName)}</span>
      <span class="active-line">${esc(line)}</span></button>`;
  }

  // Le filtre « Perso » ne s'affiche qu'une fois un jeu créé : une catégorie
  // toujours vide n'apprend rien à personne.
  const hasCustom = S.state.customGames.length > 0;
  html += `<div class="pillbar" role="group" aria-label="Filtrer par catégorie">` +
    CATEGORIES.filter(([key]) => key !== "perso" || hasCustom).map(([key, label]) =>
      `<button class="pill" data-act="filter" data-key="${key}"
        aria-pressed="${S.state.filter === key}">${label}</button>`).join("") + `</div>`;

  html += `<div class="grid-games">` + games.map((g) =>
    `<button class="gcard" data-act="pick-game" data-id="${g.id}">
      <span class="glyph">${glyph(g.id, 26, g.symbol)}</span>
      <span class="gname">${esc(g.name)}</span>
      <span class="gtype">${g.team ? "Équipe" : "Individuel"}</span></button>`).join("") +
    `<button class="gcard new" data-act="new-custom">
      <span class="glyph" aria-hidden="true">+</span>
      <span class="gname">Créer un jeu</span>
      <span class="gtype">Vos propres règles de comptage</span></button></div>`;

  return html;
}

// --- créateur de jeu ------------------------------------------------------

/**
 * Formulaire d'un jeu personnalisé.
 *
 * Les champs libres — nom, règles — vivent dans le DOM et ne sont relus qu'au
 * moment d'agir : `readCustomForm()` les récupère avant chaque redessin, sinon
 * un clic sur une pastille effacerait ce qui vient d'être tapé.
 */
function screenCustomGame() {
  // Comme les autres écrans : la navigation dit quoi éditer, `scratch` porte la
  // saisie en cours. Un jeu supprimé entre-temps ramène à un formulaire vierge.
  scratch.custom ??= view.customId
    ? { ...(S.customById(view.customId) ?? blankCustomGame()) }
    : blankCustomGame();
  const g = scratch.custom;
  const editing = Boolean(S.customById(g.id));
  const errors = scratch.customErrors ?? [];

  const chips = (name, options, current) => `<div class="chips">` + options.map(([key, label]) =>
    `<button class="chip" data-act="custom-set" data-field="${name}" data-value="${key}"
      aria-pressed="${current === key}">${esc(label)}</button>`).join("") + `</div>`;

  const engineHelp = CUSTOM_ENGINES.find(([k]) => k === g.engine)?.[2] ?? "";

  let html = `<div style="display:flex;align-items:center;gap:12px;margin-bottom:18px">
      <button class="ghost" data-act="home">‹ Jeux</button>
      <h1 style="flex:1;font-size:24px">${editing ? "Modifier le jeu" : "Créer un jeu"}</h1></div>`;

  if (errors.length) {
    html += `<div class="card" role="alert">` +
      errors.map((e) => `<p class="hint" style="margin:0;color:var(--red)">${esc(e)}</p>`).join("") +
      `</div>`;
  }

  html += `<div class="card">
      <label class="row" style="border:none;padding:0;gap:12px">
        <span class="name">Nom</span>
        <input type="text" id="custom-name" maxlength="40" value="${esc(g.name)}"
          placeholder="Belote de mon grand-père" aria-label="Nom du jeu"></label>
    </div>`;

  html += `<div class="section-label">Pictogramme</div><div class="chips">` +
    CUSTOM_SYMBOLS.map((key) =>
      `<button class="chip fixed" data-act="custom-set" data-field="symbol" data-value="${key}"
        aria-pressed="${g.symbol === key}" aria-label="Pictogramme ${key}">${glyph("", 22, key)}</button>`
    ).join("") + `</div>`;

  html += `<div class="section-label">Comment on compte</div>` +
    chips("engine", CUSTOM_ENGINES.map(([k, label]) => [k, label]), g.engine) +
    `<p class="hint" style="margin-top:-6px">${esc(engineHelp)}</p>`;

  html += `<div class="section-label">Format</div>` +
    chips("team", [["solo", "Individuel"], ["team", "Deux équipes"]], g.team ? "team" : "solo");

  // Aux manches gagnées, l'objectif se compte en petites unités : une belle se
  // joue en 3, pas en 50.
  const step = g.engine === "manche" ? 1 : (g.target > 0 && g.target < 50 ? 5 : 50);
  html += `<div class="section-label">Objectif</div><div class="card">
      <div style="display:flex;align-items:center;gap:14px">
        <button class="chip fixed" data-act="custom-target" data-delta="${-step}" aria-label="Diminuer l'objectif">−</button>
        <div style="flex:1;text-align:center">
          <div class="tab" style="font-size:19px;font-weight:600">${
            g.target === 0 ? "Fin de partie libre"
              : (g.engine === "manche" ? `${g.target} manches gagnées` : `${g.target} points`)}</div>
          <div style="font-size:13px;color:var(--ink-2)">${
            g.engine === "countdown" ? "on descend jusqu'à zéro" : (g.high ? "le + haut gagne" : "le + bas gagne")}</div>
        </div>
        <button class="chip fixed" data-act="custom-target" data-delta="${step}" aria-label="Augmenter l'objectif">+</button>
      </div></div>`;

  // Un compte à rebours gagne forcément en descendant : proposer le contraire
  // décrirait une partie que le moteur ne sait pas compter.
  if (g.engine !== "countdown") {
    html += `<div class="section-label">Qui gagne</div>` +
      chips("high", [["high", "Le plus haut score"], ["low", "Le plus bas score"]], g.high ? "high" : "low");
  }

  html += `<div class="section-label">Nombre de manches</div><div class="card">
      <div style="display:flex;align-items:center;gap:14px">
        <button class="chip fixed" data-act="custom-rounds" data-delta="-1" aria-label="Moins de manches">−</button>
        <div style="flex:1;text-align:center" class="tab" style="font-size:19px">${
          g.roundLimit === 0 ? "Libre" : `${g.roundLimit} manches`}</div>
        <button class="chip fixed" data-act="custom-rounds" data-delta="1" aria-label="Plus de manches">+</button>
      </div>
      <p class="hint" style="margin:10px 0 0">Fixé, la partie s'arrête d'elle-même au bout du compte.</p></div>`;

  html += `<div class="section-label">Règles (facultatif)</div><div class="card">
      <textarea id="custom-rules" rows="5" maxlength="2000"
        aria-label="Règles du jeu"
        placeholder="Ce qu'il faut se rappeler avant de commencer.">${esc(g.rules)}</textarea></div>`;

  html += `<button class="btn primary" data-act="save-custom">${
    editing ? "Enregistrer" : "Créer le jeu"}</button>`;
  if (editing) {
    html += `<button class="btn secondary" data-act="del-custom" data-id="${g.id}">Supprimer ce jeu</button>
      <p class="hint" style="text-align:center">Les parties déjà jouées avec lui sont conservées.</p>`;
  }
  return html;
}

function screenNewGame() {
  const g = S.gameById(view.gameId);
  scratch.assign ??= {};
  scratch.target ??= g.target;

  const counts = Object.values(scratch.assign);
  const t1 = counts.filter((v) => v === 1).length;
  const t2 = counts.filter((v) => v === 2).length;
  const canStart = g.team ? t1 > 0 && t2 > 0 : t1 >= 2;

  let html = `<h1 style="font-size:28px;margin-bottom:6px">${esc(g.name)}</h1>
    <p class="hint">${g.team
      ? "Cliquez pour assigner à une équipe, re-cliquez pour retirer."
      : "Cliquez pour ajouter ou retirer un joueur."}
      ${g.rules ? `<button class="ghost" data-act="rules" style="padding:0 4px">Voir les règles</button>` : ""}
      ${g.custom ? `<button class="ghost" data-act="edit-custom" data-id="${g.id}"
        style="padding:0 4px">Modifier ce jeu</button>` : ""}</p>
    <div class="card">`;

  html += S.state.players.map((p) => {
    const st = scratch.assign[p.id] ?? 0;
    let badge = `<span class="badge off">—</span>`;
    if (st === 1) badge = `<span class="badge">${g.team ? "Équipe 1" : "Sélectionné"}</span>`;
    if (st === 2) badge = `<span class="badge neutral">Équipe 2</span>`;
    return `<div class="row"><button class="score-row" style="border:none;background:none;padding:0;margin:0"
        data-act="cycle" data-id="${p.id}" aria-pressed="${st > 0}">
        ${avatar(p.name, p.colorIndex)}<span class="nm">${esc(p.name)}</span>${badge}</button></div>`;
  }).join("") || `<p class="hint" style="margin:0">Aucun joueur : ajoutez-en un ci-dessous.</p>`;

  html += `<div class="row" style="gap:10px">
      <input type="text" id="quick-player" placeholder="Nouveau joueur" aria-label="Nom du nouveau joueur">
      <button class="ghost" data-act="quick-add">Ajouter</button>
    </div></div>`;

  if (g.engine !== "grid" && g.engine !== "phase" && !g.roundLimit) {
    const step = g.target > 0 && g.target < 50 ? 1 : (g.engine === "countdown" ? 100 : 50);
    html += `<div class="section-label">Objectif</div><div class="card">
      <div style="display:flex;align-items:center;gap:14px">
        <button class="chip fixed" data-act="target" data-delta="${-step}" aria-label="Diminuer l'objectif">−</button>
        <div style="flex:1;text-align:center">
          <div class="tab" style="font-size:19px;font-weight:600">${
            scratch.target === 0 ? "Fin de partie libre" : `${scratch.target} points`}</div>
          <div style="font-size:13px;color:var(--ink-2)">${g.high ? "le + haut gagne" : "le + bas gagne"}</div>
        </div>
        <button class="chip fixed" data-act="target" data-delta="${step}" aria-label="Augmenter l'objectif">+</button>
      </div></div>`;
  }

  html += `<button class="btn primary" data-act="start" ${canStart ? "" : "disabled"}>Lancer la partie</button>
    <p class="hint" style="text-align:center">${g.team
      ? "Il faut au moins un joueur par équipe." : "Il faut au moins deux joueurs."}</p>`;
  return html;
}

// --- écrans de score ------------------------------------------------------

function winnerBlock(session, detail, shareText, { belle = false, replay = "Rejouer" } = {}) {
  const w = E.winnerIndex(session);
  if (w === null) return "";
  return `<div class="share-bar">
      <button class="ghost" data-act="share" data-text="${esc(shareText)}">Partager</button></div>
    <div class="winner"><div class="cup" aria-hidden="true">🏆</div>
      <div class="wt">${esc(session.entrants[w].name)} remporte la partie !</div>
      <div class="wd">${esc(detail)}</div></div>` +
    (belle
      ? `<button class="btn primary" data-act="replay" data-keep="1">La belle (rejouer en cumulant)</button>
         <button class="btn secondary" data-act="replay">Revanche (0 – 0)</button>`
      : `<button class="btn primary" data-act="replay">${esc(replay)}</button>`) +
    // « Reprendre » ne sert qu'aux parties closes à la main : celle qui s'est
    // terminée sur l'objectif se refermerait aussitôt, tant que les points
    // n'ont pas été corrigés.
    (session.manuallyFinished
      ? `<button class="btn secondary" data-act="reopen">Reprendre la partie</button>`
      : "") +
    `<button class="btn secondary" data-act="home">Changer de jeu</button>`;
}

function historyBlock(session, label, rows) {
  if (!rows) return "";
  return `<div class="section-label">${label}</div>${rows}`;
}

function genericRows(session) {
  if (!session.rounds.length) return "";
  return session.rounds.map((r, i) => ({ r, i })).reverse().map(({ r, i }) =>
    `<div class="hist"><span class="ix">M${i + 1}</span>
      <button class="hist-open" data-act="edit-round" data-i="${i}"
        aria-label="Corriger la manche ${i + 1}">
        <span class="dt tab">${session.entrants.map((e, j) =>
          `${esc(e.name.slice(0, 3))} ${r[j] ?? 0}`).join(" · ")}</span></button>
      <button class="icon-btn" data-act="del-round" data-i="${i}"
        aria-label="Supprimer la manche ${i + 1}">✕</button></div>`).join("");
}

function scoringGeneric(session, game) {
  const fin = E.isFinished(session);
  scratch.inputs ??= session.entrants.map(() => "");

  let left = `<div class="card" style="display:flex;justify-content:space-between;font-size:15px;color:var(--ink-2)">
      <span>Manche ${session.rounds.length + (fin ? 0 : 1)}${
        session.roundLimit > 0 ? ` / ${session.roundLimit}` : ""}</span>
      ${session.target > 0 ? `<span class="tab">Objectif ${session.target}</span>` : ""}</div>`;

  session.entrants.forEach((e, i) => {
    const t = E.total(session, i);
    const prog = session.target > 0 ? Math.min(1, Math.max(0, t / session.target)) : 0;
    const lead = fin && E.winnerIndex(session) === i;
    left += `<div class="card"${lead ? ' style="outline:1.5px solid var(--blue)"' : ""}>
      <div style="display:flex;align-items:center;gap:12px;margin-bottom:10px">
        ${avatar(e.name, e.colorIndex)}
        <div style="flex:1"><div style="font-weight:500">${esc(e.name)}</div>
        ${lead ? `<div style="font-size:13px;color:var(--blue)">Vainqueur</div>` : ""}</div>
        <div class="tab" style="font-size:26px;font-weight:600;letter-spacing:-.02em">${t}</div>
      </div>
      ${session.target > 0
        ? `<div class="track"><div class="fill" style="background:${HUES[e.colorIndex % HUES.length]};width:${prog * 100}%"></div></div>`
        : ""}</div>`;
  });

  let right = "";
  if (fin) {
    const w = E.winnerIndex(session);
    right = winnerBlock(session,
      `${E.total(session, w)} pts · ${session.rounds.length} manches`,
      `🏆 ${session.entrants[w].name} remporte ${session.gameName} avec ${E.total(session, w)} points en ${session.rounds.length} manches ! Compté avec Scornade.`,
      { replay: "Rejouer (0 – 0)" });
  } else {
    right = `<div class="card"><p class="hint">Points de la manche</p>` +
      session.entrants.map((e, i) =>
        `<div class="row" style="border:none;padding:7px 0">
          ${avatar(e.name, e.colorIndex, true)}<span class="name">${esc(e.name)}</span>
          <input type="number" inputmode="numeric" class="num short entry" data-i="${i}"
            value="${esc(scratch.inputs[i])}" placeholder="0" aria-label="Points de ${esc(e.name)}"></div>`).join("") +
      `<button class="btn primary" style="margin-top:14px" data-act="validate-generic">Valider la manche</button>
       </div>`;
  }

  return { left: left + historyBlock(session, "Historique · touchez une manche pour la corriger",
                                     genericRows(session)), right };
}

/**
 * Phase 10.
 *
 * Ce jeu ne se gagne pas aux points : on gagne en posant sa dixième phase, et
 * les points ne servent qu'à départager ceux qui y arrivent dans la même
 * manche. Une manche demande donc deux choses par joueur — sa phase est-elle
 * passée, et combien de points lui restaient en main.
 */
function scoringPhase10(session) {
  const fin = E.isFinished(session);
  scratch.inputs ??= session.entrants.map(() => "");
  scratch.phaseDone ??= session.entrants.map(() => false);

  let left = `<div class="card" style="display:flex;justify-content:space-between;font-size:15px;color:var(--ink-2)">
      <span>Manche ${session.rounds.length + (fin ? 0 : 1)}</span>
      <span class="tab">Les points départagent</span></div>`;

  left += session.entrants.map((e, i) => {
    const phase = E.phaseOf(session, i);
    return `<div class="score-row">${avatar(e.name, e.colorIndex, true)}
      <span class="nm">${esc(e.name)}<br>
        <span class="sub">${phase > 10 ? "Dix phases posées" : `Phase ${phase} sur 10`}</span></span>
      <span class="sc">${E.total(session, i)}</span></div>`;
  }).join("");

  let right = "";
  if (fin) {
    const w = E.winnerIndex(session);
    right = winnerBlock(session,
      `Dix phases posées · ${E.total(session, w)} pts de pénalité`,
      `🏆 ${session.entrants[w].name} boucle les dix phases de ${session.gameName} avec ${E.total(session, w)} points de pénalité ! Compté avec Scornade.`,
      { replay: "Rejouer (0 – 0)" });
  } else {
    right = `<div class="card"><p class="hint">Phase posée, et points restés en main</p>` +
      session.entrants.map((e, i) => {
        const phase = E.phaseOf(session, i);
        return `<div class="row" style="border:none;padding:7px 0">
          <button class="chip fixed" data-act="phase-done" data-i="${i}"
            aria-pressed="${scratch.phaseDone[i]}"
            aria-label="Phase ${phase} posée par ${esc(e.name)}">${scratch.phaseDone[i] ? "✓" : "—"}</button>
          <span class="name">${esc(e.name)}<br>
            <span class="sub">Phase ${phase} — ${esc(E.PHASE10_PHASES[Math.min(phase, 10) - 1])}</span></span>
          <input type="number" inputmode="numeric" class="num short entry" data-i="${i}"
            value="${esc(scratch.inputs[i])}" placeholder="0"
            aria-label="Points restants de ${esc(e.name)}"></div>`;
      }).join("") +
      `<p class="hint">5 points par carte de 1 à 9, 10 de 10 à 12, 15 pour un « Passe », 25 pour un joker.</p>
       <button class="btn primary" data-act="validate-phase">Valider la manche</button>
       </div>`;
  }

  return { left: left + historyBlock(session, "Manches jouées", phaseRows(session)), right };
}

/** Comme `genericRows`, mais la coche dit en plus qui a posé sa phase. */
function phaseRows(session) {
  if (!session.rounds.length) return "";
  return session.rounds.map((r, i) => ({ r, i })).reverse().map(({ r, i }) =>
    `<div class="hist"><span class="ix">M${i + 1}</span>
      <button class="hist-open" data-act="edit-round" data-i="${i}"
        aria-label="Corriger la manche ${i + 1}">
        <span class="dt tab">${session.entrants.map((e, j) =>
          `${esc(e.name.slice(0, 3))} ${session.phaseRounds?.[i]?.[j] ? "✓" : "·"} ${r[j] ?? 0}`)
          .join(" · ")}</span></button>
      <button class="icon-btn" data-act="del-round" data-i="${i}"
        aria-label="Supprimer la manche ${i + 1}">✕</button></div>`).join("");
}

// Le complément à 250 va au joueur qu'on n'a pas saisi, et non au dernier de la
// liste : celui qui n'a rien ramassé n'est presque jamais le dernier joueur.
// Si plusieurs cases sont vides, la case active tranche, sinon la dernière vide.
// Sans case vide, on recalcule celle qui a le curseur, à défaut la dernière.
function payooFillIndex(inputs, focus) {
  const blanks = inputs.reduce((a, v, i) => (String(v).trim() === "" ? [...a, i] : a), []);
  const focused = Number.isInteger(focus) && focus >= 0 && focus < inputs.length ? focus : null;
  if (blanks.length) return blanks.includes(focused) ? focused : blanks[blanks.length - 1];
  return focused ?? inputs.length - 1;
}

function scoringPayoo(session) {
  const fin = E.isFinished(session);
  scratch.inputs ??= session.entrants.map(() => "");
  const sum = scratch.inputs.reduce((a, v) => a + (parseInt(v, 10) || 0), 0);
  const exact = sum === E.PAYOO_ROUND_TOTAL;
  const fillIdx = payooFillIndex(scratch.inputs, scratch.entryFocus);

  const totals = session.entrants.map((_, i) => E.total(session, i));
  const lead = totals.indexOf(Math.min(...totals));
  let left = session.entrants.map((e, i) =>
    `<div class="score-row">${avatar(e.name, e.colorIndex, true)}
      <span class="nm">${esc(e.name)}</span>
      ${session.rounds.length && i === lead ? `<span style="color:var(--yellow)">♛</span>` : ""}
      <span class="sc">${totals[i]}</span></div>`).join("");

  let right = "";
  if (fin) {
    const w = E.winnerIndex(session);
    right = winnerBlock(session,
      `${E.total(session, w)} pts · ${session.rounds.length} manches`,
      `🏆 ${session.entrants[w].name} remporte Papayoo avec ${E.total(session, w)} points en ${session.rounds.length} manches ! Compté avec Scornade.`,
      { replay: "Rejouer (0 – 0)" });
  } else {
    right = `<div class="card"><p class="hint">Points ramassés cette manche</p>` +
      session.entrants.map((e, i) =>
        `<div class="row" style="border:none;padding:7px 0">
          ${avatar(e.name, e.colorIndex, true)}<span class="name">${esc(e.name)}</span>
          <input type="number" inputmode="numeric" class="num short entry" data-i="${i}"
            value="${esc(scratch.inputs[i])}" placeholder="0" aria-label="Points de ${esc(e.name)}"></div>`).join("") +
      `<div style="display:flex;align-items:center;justify-content:space-between;gap:12px;margin-top:12px">
         <button class="chip fixed" data-act="payoo-fill">Compléter ${esc(session.entrants[fillIdx].name)} à 250</button>
         <span class="tab" style="font-weight:500;color:${exact ? "var(--green)" : "var(--red)"}">${sum} / 250</span>
       </div>
       <button class="btn primary" style="margin-top:12px" data-act="payoo-validate"
         ${exact ? "" : "disabled"}>Valider la manche</button>
       ${exact ? "" : `<p class="hint" style="margin:10px 0 0">Une manche distribue exactement 250 points.</p>`}
       </div>`;
  }

  return { left: left + historyBlock(session, "Manches jouées", genericRows(session)), right };
}

function scoringBelote(session) {
  const fin = E.isFinished(session);
  const f = (scratch.belote ??= { taker: null, suit: null, p0: "", p1: "", b0: false, b1: false, capot: null });
  const p0 = parseInt(f.p0, 10) || 0;
  const p1 = parseInt(f.p1, 10) || 0;
  const sum = p0 + p1;
  const canValidate = f.taker !== null && f.suit !== null && (f.capot !== null || sum === 162);
  // Points laissés en jeu par un litige : ils iront au camp qui gagne la donne.
  const pending = E.belotePending(session.beloteRounds ?? []);

  let left = "";
  if (session.seriesWins) {
    left += `<p style="text-align:center;font-size:14px;font-weight:500;color:var(--blue);margin:0 0 12px">
      Manches gagnées · É1 ${session.seriesWins[0]} – ${session.seriesWins[1]} É2</p>`;
  }
  left += `<div class="teams">`;
  [0, 1].forEach((t) => {
    const tp = E.total(session, t);
    const prog = session.target > 0 ? Math.min(1, tp / session.target) : 0;
    left += `<div class="team t${t + 1}"><div class="tl">Équipe ${t + 1}</div>
      <div class="tn">${esc(session.entrants[t]?.name ?? "—")}</div>
      <div class="ts">${tp}</div>
      <div class="track"><div class="fill" style="width:${prog * 100}%"></div></div></div>`;
    if (t === 0) left += `<div class="objective">objectif<b>${session.target}</b></div>`;
  });
  left += `</div>`;

  const rows = session.beloteRounds?.length
    ? session.beloteRounds.map((r, i) => ({ r, i })).reverse().map(({ r, i }) => {
        const d = E.beloteDeltas(r);
        const outcome = E.beloteOutcome(r);
        const mark = { fait: "✓", litige: "litige", chute: "chute" }[outcome];
        const cls = { fait: "ok", litige: "tie", chute: "ko" }[outcome];
        return `<div class="hist"><span class="ix">D${i + 1}</span>
          <span class="dt">É${r.takerTeam + 1} prend ${r.suit}</span>
          <span class="st ${cls}">${mark}</span>
          <span class="tab" style="font-size:13px">${d[0]} – ${d[1]}</span>
          <button class="icon-btn" data-act="del-round" data-i="${i}"
            aria-label="Supprimer la donne ${i + 1}">✕</button></div>`;
      }).join("")
    : "";
  left += historyBlock(session, "Donnes jouées", rows);

  let right = "";
  if (fin) {
    const w = E.winnerIndex(session);
    right = winnerBlock(session,
      `${E.total(session, w)} – ${E.total(session, 1 - w)} · ${session.rounds.length} donnes`,
      `🃏 ${session.entrants[w].name} remporte la Belote ${E.total(session, w)} – ${E.total(session, 1 - w)} en ${session.rounds.length} donnes ! Compté avec Scornade.`,
      { belle: true });
  } else {
    right = `<div class="card">
      <p class="hint">Qui prend ?</p><div class="chips">` +
      [0, 1].map((t) => `<button class="chip" data-act="b-taker" data-v="${t}"
        aria-pressed="${f.taker === t}">${esc(session.entrants[t].name)}</button>`).join("") +
      `</div><p class="hint">Atout</p><div class="chips">` +
      ["♠", "♥", "♦", "♣"].map((s) => `<button class="chip suit${s === "♥" || s === "♦" ? " red" : ""}"
        data-act="b-suit" data-v="${s}" aria-pressed="${f.suit === s}">${s}</button>`).join("") +
      `</div>` +
      (pending ? `<p class="note tie" style="margin:12px 0 0">${pending} points sont en jeu, laissés par le
         litige : ils reviennent au camp qui remporte cette donne.</p>` : "") +
      `<p class="hint">Points aux cartes (total 162)</p>
      <div style="display:flex;gap:12px;margin-bottom:10px">
        <div style="flex:1"><label class="field" for="b-p0">Équipe 1</label>
          <input type="number" inputmode="numeric" class="num b-pts" id="b-p0" data-t="0"
            value="${esc(f.p0)}" placeholder="0" ${f.capot !== null ? "disabled" : ""}></div>
        <div style="flex:1"><label class="field" for="b-p1">Équipe 2</label>
          <input type="number" inputmode="numeric" class="num b-pts" id="b-p1" data-t="1"
            value="${esc(f.p1)}" placeholder="0" ${f.capot !== null ? "disabled" : ""}></div>
      </div>
      <p class="note${f.capot !== null || sum === 162 ? " ok" : ""}" style="margin:0 0 12px">${
        f.capot !== null ? "Capot — points automatiques"
          : sum === 162 ? `${p0} + ${p1} = 162 ✓` : `${p0} + ${p1} = ${sum} (doit faire 162)`}</p>
      <p class="hint">Annonces &amp; bonus</p><div class="chips">
        <button class="chip" data-act="b-belote" data-v="0" aria-pressed="${f.b0}">Belote É1</button>
        <button class="chip" data-act="b-belote" data-v="1" aria-pressed="${f.b1}">Belote É2</button></div>
      <div class="chips">
        <button class="chip" data-act="b-capot" data-v="0" aria-pressed="${f.capot === 0}">Capot É1</button>
        <button class="chip" data-act="b-capot" data-v="1" aria-pressed="${f.capot === 1}">Capot É2</button></div>`;

    if (canValidate) {
      const round = { takerTeam: f.taker, suit: f.suit, cardPoints: [p0, p1],
                      belote: [f.b0, f.b1], capotTeam: f.capot, pending };
      const d = E.beloteDeltas(round);
      const outcome = E.beloteOutcome(round);
      const takerName = esc(session.entrants[f.taker].name);
      const title = {
        fait: `${takerName} réussit son contrat ${f.suit}`,
        litige: `Litige — 81 partout`,
        chute: `${takerName} est dedans — chute !`,
      }[outcome];
      const cls = { fait: "ok", litige: "tie", chute: "ko" }[outcome];
      right += `<div class="result ${cls}">
        <b>${title}</b>
        ${outcome === "litige"
          ? `<p style="margin:0 0 6px;font-size:13px">${takerName} ne marque rien : ses ${E.BELOTE_LITIGE} points
             sont remis en jeu pour la donne suivante, où ${pending + E.BELOTE_LITIGE} points seront en jeu.</p>`
          : ""}
        <div class="ln"><span>Équipe 1</span><span>+${d[0]} pts</span></div>
        <div class="ln"><span>Équipe 2</span><span>+${d[1]} pts</span></div></div>`;
    }
    right += `<button class="btn primary" data-act="b-validate" ${canValidate ? "" : "disabled"}>
      Valider la donne</button></div>`;
  }

  return { left, right };
}

function scoringDarts(session) {
  const fin = E.isFinished(session);
  scratch.current ??= 0;
  const totals = session.entrants.map((_, i) => E.total(session, i));
  const lead = totals.indexOf(Math.min(...totals));

  const left = session.entrants.map((e, i) =>
    `<button class="score-row" data-act="pick-player" data-i="${i}" aria-pressed="${scratch.current === i}">
      ${avatar(e.name, e.colorIndex, true)}<span class="nm">${esc(e.name)}</span>
      ${session.rounds.length && i === lead ? `<span style="color:var(--blue)">◎</span>` : ""}
      <span class="sc">${totals[i]}</span></button>`).join("");

  let right;
  if (fin) {
    const w = E.winnerIndex(session);
    right = winnerBlock(session, `501 → 0 · ${session.rounds.length} volées`,
      `🎯 ${session.entrants[w].name} remporte les fléchettes en ${session.rounds.length} volées ! Compté avec Scornade.`,
      { replay: "Rejouer (501)" });
  } else {
    right = `<div class="card">
      <div style="display:flex;justify-content:space-between;margin-bottom:12px">
        <span class="hint" style="margin:0">Volée de ${esc(session.entrants[scratch.current].name)}</span>
        <span class="tab" style="font-weight:500;color:var(--blue)">reste ${E.total(session, scratch.current)}</span></div>
      <div style="display:flex;gap:8px;margin-bottom:12px">
        <input type="number" inputmode="numeric" class="num" id="dart-input"
          placeholder="Points (0–180)" aria-label="Points de la volée">
        <button class="chip fixed" data-act="dart-submit">Valider</button></div>
      <div class="chips">` +
      [26, 41, 45, 60, 85, 100, 140, 180].map((q) =>
        `<button class="chip" data-act="dart" data-v="${q}">${q}</button>`).join("") +
      `</div><div class="chips">
        <button class="chip" data-act="dart" data-v="0">Manqué (0)</button>
        <button class="chip" data-act="undo" ${session.rounds.length ? "" : "disabled"}>Annuler</button></div>
      ${scratch.note ? `<p class="note">${esc(scratch.note)}</p>` : ""}</div>`;
  }
  return { left, right };
}

function scoringMolkky(session) {
  const fin = E.isFinished(session);
  scratch.current ??= 0;
  const totals = session.entrants.map((_, i) => E.total(session, i));
  const lead = totals.indexOf(Math.max(...totals));

  const left = session.entrants.map((e, i) => {
    const out = session.molkkyOut?.[i];
    return `<button class="score-row${out ? " out" : ""}" data-act="pick-player" data-i="${i}"
      aria-pressed="${scratch.current === i}" ${out ? "disabled" : ""}>
      ${avatar(e.name, e.colorIndex, true)}<span class="nm">${esc(e.name)}</span>
      ${out ? `<span style="color:var(--red);font-size:13px">éliminé</span>`
            : session.rounds.length && i === lead ? `<span style="color:var(--blue)">⬤</span>` : ""}
      <span class="sc">${totals[i]}</span></button>`;
  }).join("");

  let right;
  if (fin) {
    const w = E.winnerIndex(session);
    right = winnerBlock(session, `50 points pile · ${session.rounds.length} lancers`,
      `🏆 ${session.entrants[w].name} remporte le Mölkky avec 50 points pile ! Compté avec Scornade.`);
  } else {
    right = `<div class="card">
      <div style="display:flex;justify-content:space-between;margin-bottom:12px">
        <span class="hint" style="margin:0">Lancer de ${esc(session.entrants[scratch.current].name)}</span>
        <span class="tab" style="font-weight:500;color:var(--blue)">${E.total(session, scratch.current)} / 50</span></div>
      <div class="chips">` +
      Array.from({ length: 12 }, (_, k) => k + 1).map((q) =>
        `<button class="chip fixed" data-act="molkky" data-v="${q}">${q}</button>`).join("") +
      `</div><div class="chips">
        <button class="chip" data-act="molkky" data-v="0">Raté (0)</button>
        <button class="chip" data-act="undo" ${session.rounds.length ? "" : "disabled"}>Annuler</button></div>
      ${scratch.note ? `<p class="note">${esc(scratch.note)}</p>` : ""}
      <p class="hint" style="margin:12px 0 0">Trois ratés d'affilée éliminent le joueur.</p></div>`;
  }
  return { left, right };
}

function scoringYams(session) {
  const done = E.yamsAllFilled(session) || session.manuallyFinished;
  scratch.selected ??= 0;
  const p = Math.min(scratch.selected, session.entrants.length - 1);

  const left = `<div class="pillbar">` + session.entrants.map((e, i) =>
    `<button class="pill" data-act="yams-player" data-i="${i}" aria-pressed="${scratch.selected === i}">
      ${esc(e.name)} · ${E.yamsTotal(session, i)}</button>`).join("") + `</div>`;

  if (done) {
    const totals = session.entrants.map((_, i) => E.yamsTotal(session, i));
    const w = totals.indexOf(Math.max(...totals));
    return {
      left,
      right: `<div class="share-bar"><button class="ghost" data-act="share"
          data-text="🎲 ${esc(session.entrants[w].name)} remporte le Yam's avec ${totals[w]} points ! Compté avec Scornade.">Partager</button></div>
        <div class="winner"><div class="cup" aria-hidden="true">🏆</div>
          <div class="wt">${esc(session.entrants[w].name)} remporte la partie !</div>
          <div class="wd">${totals[w]} points</div></div>
        <button class="btn primary" data-act="replay">Rejouer</button>
        <button class="btn secondary" data-act="home">Changer de jeu</button>`,
    };
  }

  let right = `<div class="card"><h2 style="font-size:19px;margin-bottom:12px">Grille de ${esc(session.entrants[p].name)}</h2>
    <div class="section-label" style="margin-top:0">Partie supérieure</div>`;
  for (let c = 0; c < 6; c++) {
    const v = E.yamsCell(session, p, c);
    right += `<div class="yrow"><span class="yl">${E.YAMS_CATEGORIES[c][0]}</span>
      <input type="number" inputmode="numeric" class="num yams-cell" data-p="${p}" data-c="${c}"
        value="${v < 0 ? "" : v}" placeholder="—" aria-label="${E.YAMS_CATEGORIES[c][0]}"></div>`;
  }
  right += `<div class="ysum${E.yamsUpper(session, p) >= 63 ? " good" : ""}">
      <span>Sous-total</span><b>${E.yamsUpper(session, p)} / 63</b></div>
    <div class="ysum${E.yamsBonus(session, p) > 0 ? " good" : ""}">
      <span>Bonus (+35 si ≥ 63)</span><b>+${E.yamsBonus(session, p)}</b></div>
    <div class="section-label">Partie inférieure</div>`;
  for (let c = 6; c < 13; c++) {
    const v = E.yamsCell(session, p, c);
    const fixed = E.YAMS_CATEGORIES[c][1];
    right += `<div class="yrow"><span class="yl">${E.YAMS_CATEGORIES[c][0]}</span>`;
    right += fixed !== null
      ? `<button class="chip fixed" data-act="yams-fixed" data-p="${p}" data-c="${c}" data-v="${fixed}"
           aria-pressed="${v === fixed}">${fixed}</button>
         <button class="chip fixed" data-act="yams-fixed" data-p="${p}" data-c="${c}" data-v="0"
           aria-pressed="${v === 0}">0</button>`
      : `<input type="number" inputmode="numeric" class="num yams-cell" data-p="${p}" data-c="${c}"
           value="${v < 0 ? "" : v}" placeholder="—" aria-label="${E.YAMS_CATEGORIES[c][0]}">`;
    right += `</div>`;
  }
  right += `<div class="ytotal"><span style="font-weight:500">TOTAL</span>
    <span class="val">${E.yamsTotal(session, p)}</span></div></div>`;

  return { left, right };
}

function screenScoring() {
  const session = S.sessionById(view.id);
  if (!session) return `<div class="empty">Partie introuvable.</div>`;
  const game = S.gameById(session.gameId);

  let parts;
  // Un jeu personnalisé n'a que le comptage générique : c'est le seul qui ne
  // suppose rien de la façon dont on joue. Un jeu supprimé depuis — `game` est
  // alors introuvable — se lit de la même façon : tout ce qu'il faut pour
  // afficher la partie est dans la partie elle-même.
  if (!game || isCustomGame(game.id)) parts = scoringGeneric(session, game);
  else if (game.id === "belote") parts = scoringBelote(session);
  else if (game.engine === "payoo") parts = scoringPayoo(session);
  else if (game.engine === "countdown") parts = scoringDarts(session);
  else if (game.engine === "molkky") parts = scoringMolkky(session);
  else if (game.engine === "grid") parts = scoringYams(session);
  else if (game.engine === "phase") parts = scoringPhase10(session);
  else parts = scoringGeneric(session, game);

  const head = `<div style="display:flex;align-items:center;gap:12px;margin-bottom:18px">
      <button class="ghost" data-act="home">‹ Jeux</button>
      <h1 style="flex:1;font-size:24px">${esc(session.gameName)}</h1>
      ${E.isFinished(session) ? "" :
        `<button class="ghost" data-act="finish">Terminer</button>`}
    </div>`;

  return head + `<div class="split"><div>${parts.left}</div><div>${parts.right}</div></div>`;
}

function screenPlayers() {
  let html = `<h1 style="font-size:28px;margin-bottom:18px">Joueurs</h1>
    <div class="card"><div class="row" style="gap:10px;border:none;padding:0">
      <input type="text" id="new-player" placeholder="Nom du joueur" aria-label="Nom du joueur">
      <button class="ghost" data-act="add-player">Ajouter</button></div></div>`;

  html += `<div class="card">` + (S.state.players.map((p) =>
    `<div class="row">${avatar(p.name, p.colorIndex)}
      <span class="name">${esc(p.name)}</span>
      <button class="icon-btn" data-act="del-player" data-id="${p.id}"
        aria-label="Supprimer ${esc(p.name)}">Supprimer</button></div>`).join("")
    || `<p class="hint" style="margin:0">Aucun joueur pour l'instant.</p>`) + `</div>`;

  html += `<div class="section-label">Apparence</div><div class="card">
    <label class="field" for="theme-select">Thème</label>
    <select id="theme-select">
      <option value="system">Automatique (système)</option>
      <option value="light">Clair</option>
      <option value="dark">Sombre</option>
    </select></div>`;

  html += `<div class="section-label">Compte</div><div class="card">`;
  if (S.state.user) {
    html += `<div class="row" style="border:none;padding:0 0 12px">
      <span class="name">${esc(S.state.user.name)}</span>
      <span class="sub">${S.state.user.mode === "apple" ? "Apple" : "Google"}</span></div>`;
  } else {
    html += `<p class="hint">Aucun compte : les parties restent dans ce navigateur.</p>`;
  }
  html += `</div>`;
  if (S.state.user) html += `<button class="btn secondary" data-act="sign-out">Se déconnecter</button>`;
  html += `<button class="btn danger" data-act="wipe">Supprimer mes données</button>`;
  return html;
}

/**
 * Les parties terminées, de la plus récente à la plus ancienne.
 *
 * Sans cet écran, une partie sortait de l'interface dès qu'on la quittait :
 * elle nourrissait encore les statistiques, mais plus rien ne permettait d'y
 * revenir pour corriger une saisie.
 */
function screenHistory() {
  const finished = S.state.sessions
    .filter(E.isFinished)
    .slice()
    .sort((a, b) => new Date(b.date) - new Date(a.date));

  let html = `<h1 style="font-size:28px;margin-bottom:18px">Historique</h1>`;
  if (!finished.length) {
    return html + `<div class="empty">Les parties que vous aurez terminées s'afficheront ici,
      et vous pourrez y revenir pour corriger les points.</div>`;
  }

  html += `<div class="card">` + finished.map((s) => {
    const w = E.winnerIndex(s);
    const scores = s.entrants.map((e, i) => `${esc(e.name)} ${E.total(s, i)}`).join(" · ");
    const when = new Date(s.date).toLocaleDateString("fr-FR",
      { day: "numeric", month: "short", year: "numeric" });
    return `<div class="row">
      <span class="glyph" style="width:28px">${glyph(s.gameId, 20, s.symbol)}</span>
      <button class="hist-open" data-act="open-session" data-id="${s.id}">
        <span class="name">${esc(s.gameName)}</span>
        <span class="sub tab">${scores}</span>
      </button>
      <span class="sub" style="text-align:right">
        ${w === null ? "" : `🏆 ${esc(s.entrants[w].name)}<br>`}${when}</span>
      <button class="icon-btn" data-act="del-session" data-id="${s.id}"
        aria-label="Supprimer la partie de ${esc(s.gameName)}">✕</button></div>`;
  }).join("") + `</div>`;
  return html;
}

/**
 * Statistiques d'un joueur, filtrables.
 *
 * Trois filtres sur une seule ligne, au-dessus de tout ce qu'ils cadrent :
 * joueur, jeu, coéquipier. Tout ce qui suit se recalcule sur la même tranche,
 * pour que les chiffres ne se contredisent jamais entre deux blocs.
 */
function screenStats() {
  if (!S.state.players.length) {
    return `<h1 style="font-size:28px;margin-bottom:18px">Statistiques</h1>
      <div class="empty">Ajoutez des joueurs et terminez une partie pour voir les statistiques apparaître ici.</div>`;
  }
  scratch.statPlayer ??= S.state.players[0].id;
  const player = S.playerById(scratch.statPlayer) ?? S.state.players[0];
  scratch.statGame ??= "all";
  scratch.statMate ??= "all";

  // Toutes les parties terminées où ce joueur figure — avant les filtres jeu et
  // coéquipier, qui servent à peupler les listes déroulantes.
  const mine = S.state.sessions.filter(E.isFinished).map((s) => {
    const idx = s.entrants.findIndex((e) => e.playerIds.includes(player.id));
    return idx < 0 ? null : { s, idx, win: E.winnerIndex(s) === idx };
  }).filter(Boolean);

  const gameChoices = new Map();
  const mateChoices = new Map();
  mine.forEach(({ s, idx }) => {
    gameChoices.set(s.gameId, s.gameName);
    s.entrants[idx].playerIds.filter((id) => id !== player.id)
      .forEach((id) => mateChoices.set(id, S.playerById(id)?.name ?? "Joueur retiré"));
  });

  // Un filtre qui ne correspond plus à rien — le coéquipier a été supprimé —
  // bloquerait l'écran sur zéro partie sans dire pourquoi. On le relâche.
  if (scratch.statGame !== "all" && !gameChoices.has(scratch.statGame)) scratch.statGame = "all";
  if (scratch.statMate !== "all" && !mateChoices.has(scratch.statMate)) scratch.statMate = "all";

  const rows = mine.filter(({ s, idx }) =>
    (scratch.statGame === "all" || s.gameId === scratch.statGame) &&
    (scratch.statMate === "all" || s.entrants[idx].playerIds.includes(scratch.statMate)));

  let played = 0, won = 0;
  const perGame = new Map(), teammates = new Map(), opponents = new Map();
  rows.forEach(({ s, idx, win }) => {
    played++; if (win) won++;
    const g = perGame.get(s.gameId) ?? { name: s.gameName, p: 0, w: 0 };
    g.p++; if (win) g.w++; perGame.set(s.gameId, g);
    s.entrants[idx].playerIds.filter((id) => id !== player.id).forEach((id) => {
      const t = teammates.get(id) ?? { p: 0, w: 0 };
      t.p++; if (win) t.w++; teammates.set(id, t);
    });
    s.entrants.forEach((e, i) => {
      if (i === idx) return;
      e.playerIds.forEach((id) => {
        const o = opponents.get(id) ?? { p: 0, w: 0 };
        o.p++; if (win) o.w++; opponents.set(id, o);
      });
    });
  });
  const rate = played ? Math.round((won / played) * 100) : 0;

  const option = (v, label, sel) =>
    `<option value="${esc(v)}"${v === sel ? " selected" : ""}>${esc(label)}</option>`;

  let html = `<h1 style="font-size:28px;margin-bottom:14px">Statistiques</h1>
    <div class="filters">
      <label><span class="field">Joueur</span>
        <select id="stat-player">${S.state.players.map((p) =>
          option(p.id, p.name, player.id)).join("")}</select></label>
      <label><span class="field">Jeu</span>
        <select id="stat-game">${option("all", "Tous les jeux", scratch.statGame)}${
          [...gameChoices].map(([id, name]) => option(id, name, scratch.statGame)).join("")}</select></label>
      <label><span class="field">Coéquipier</span>
        <select id="stat-mate">${option("all", "Peu importe", scratch.statMate)}${
          [...mateChoices].map(([id, name]) => option(id, name, scratch.statMate)).join("")}</select></label>
    </div>`;

  if (!played) {
    return html + `<div class="empty">Aucune partie terminée ne correspond à ces filtres.</div>`;
  }

  // Bilan : quatre nombres et une jauge. Un camembert « gagnées / perdues »
  // dirait la même chose en moins lisible.
  html += `<div class="card">
      <div class="statgrid">
        <div><div class="v">${played}</div><div class="k">Jouées</div></div>
        <div><div class="v">${won}</div><div class="k">Gagnées</div></div>
        <div><div class="v">${played - won}</div><div class="k">Perdues</div></div>
        <div><div class="v">${rate} %</div><div class="k">Victoires</div></div>
      </div>
      ${C.meter(rate, "Taux de victoire")}</div>`;

  // L'anneau ne dit quelque chose que sur plusieurs jeux : filtré sur un seul,
  // il n'aurait qu'une part.
  const gameEntries = [...perGame.entries()]
    .map(([id, v]) => ({ key: id, label: v.name, value: v.p }))
    .sort((a, b) => b.value - a.value);

  if (gameEntries.length > 1) {
    const folded = C.foldTail(gameEntries);
    html += `<div class="section-label">Répartition des parties</div>
      <div class="card chart-card">
        ${C.donut(folded, { centerValue: played, centerLabel: played > 1 ? "parties" : "partie" })}
        ${C.donutLegend(folded)}</div>`;
  }

  // Toutes les barres de l'écran se mesurent sur la même échelle — le plus
  // grand nombre de parties jouées, quel que soit le bloc — pour qu'une
  // longueur veuille dire la même chose partout.
  const maxPlayed = Math.max(
    ...[...perGame.values(), ...teammates.values(), ...opponents.values()].map((v) => v.p), 1);

  const winBars = (entries, title, byPlayer) => {
    if (!entries.length) return "";
    return `<div class="section-label">${title}</div><div class="card">` +
      C.winBars(entries.map((e) => ({
        label: e.name,
        won: e.w,
        played: e.p,
        lead: byPlayer ? avatar(e.name, e.colorIndex ?? 0, true) : "",
      })), { maxPlayed }) + C.winBarsKey() + `</div>`;
  };

  if (perGame.size > 1) {
    html += winBars([...perGame.values()].sort((a, b) => b.p - a.p)
      .map((v) => ({ name: v.name, p: v.p, w: v.w })), "Victoires par jeu", false);
  }

  const peers = (map) => [...map.entries()].map(([id, v]) => {
    const who = S.playerById(id);
    return { name: who?.name ?? "Joueur retiré", colorIndex: who?.colorIndex ?? 0, p: v.p, w: v.w };
  }).sort((a, b) => b.p - a.p);

  html += winBars(peers(teammates), "Avec qui", true);
  html += winBars(peers(opponents), "Contre qui", true);

  // Le tableau est l'équivalent lisible sans couleur, exigé dès qu'une teinte
  // porte une information. Il n'est pas un repli : il dit exactement la même
  // chose que les graphiques.
  html += `<details class="table-view"><summary>Voir les chiffres</summary>
    <table><thead><tr><th>Jeu</th><th>Jouées</th><th>Gagnées</th><th>Taux</th></tr></thead><tbody>` +
    [...perGame.values()].sort((a, b) => b.p - a.p).map((v) =>
      `<tr><td>${esc(v.name)}</td><td class="tab">${v.p}</td><td class="tab">${v.w}</td>
        <td class="tab">${v.p ? Math.round((v.w / v.p) * 100) : 0} %</td></tr>`).join("") +
    `</tbody></table></details>`;

  return html;
}

// --- rendu ----------------------------------------------------------------

const NAV = [
  ["home", "Jeux"],
  ["history", "Historique"],
  ["players", "Joueurs"],
  ["stats", "Statistiques"],
];

export function render() {
  const root = document.getElementById("app");

  if (requiresSignIn()) {
    root.innerHTML = `<div class="shell"><div class="content">${screenLogin()}</div></div>`;
    return;
  }

  let body;
  switch (view.screen) {
    case "new": body = screenNewGame(); break;
    case "custom": body = screenCustomGame(); break;
    case "score": body = screenScoring(); break;
    case "history": body = screenHistory(); break;
    case "players": body = screenPlayers(); break;
    case "stats": body = screenStats(); break;
    default: body = screenHome();
  }

  const rail = `<nav class="rail" aria-label="Navigation principale">
      <div class="brand">Scornade</div>` +
    NAV.map(([key, label]) =>
      `<button class="rail-link" data-act="nav" data-screen="${key}"
        ${view.screen === key ? 'aria-current="page"' : ""}>${label}</button>`).join("") +
    `<div class="rail-foot">
      ${S.state.user ? `<button class="rail-link" data-act="sign-out">Se déconnecter</button>` : ""}
      <a class="rail-link" href="politique-de-confidentialite.html">Confidentialité</a>
    </div></nav>`;

  const topbar = `<header class="topbar">
      <div class="brand">Scornade</div>` +
    NAV.filter(([k]) => k !== view.screen).map(([key, label]) =>
      `<button class="ghost" data-act="nav" data-screen="${key}">${label}</button>`).join("") +
    `</header>`;

  root.innerHTML = `<div class="shell">${rail}<div style="flex:1;display:flex;flex-direction:column">
      ${topbar}<main class="content">${body}</main></div></div>`;

  const themeSelect = document.getElementById("theme-select");
  if (themeSelect) themeSelect.value = S.getTheme();
}

// --- interactions ---------------------------------------------------------

function currentSession() { return view.id ? S.sessionById(view.id) : null; }

/** Recopie les champs libres du créateur de jeu dans `scratch` avant redessin. */
function readCustomForm() {
  if (!scratch.custom) return;
  const name = document.getElementById("custom-name");
  const rules = document.getElementById("custom-rules");
  if (name) scratch.custom.name = name.value;
  if (rules) scratch.custom.rules = rules.value;
  scratch.customErrors = null;
}

function playTurn(session, outcome) {
  if (!outcome) return;
  const deltas = session.entrants.map(() => 0);
  deltas[scratch.current] = outcome.delta;
  const note = outcome.note;
  const advance = outcome.advance;
  S.addRound(session, deltas);
  scratch.note = note;
  if (advance) {
    const n = session.entrants.length;
    let next = (scratch.current + 1) % n;
    let guard = 0;
    while (session.molkkyOut?.[next] && guard < n) { next = (next + 1) % n; guard++; }
    scratch.current = next;
  }
}

export function bindEvents() {
  const root = document.getElementById("app");

  // La feuille modale vit à côté de `#app`, pas dedans : ses clics ne
  // remontaient donc pas jusqu'ici, et son bouton « Fermer » ne faisait rien.
  // On lui accroche le même gestionnaire.
  const onClick = (ev) => {
    const el = ev.target.closest("[data-act]");
    if (!el) return;
    const act = el.dataset.act;
    const session = currentSession();

    switch (act) {
      case "nav": go({ screen: el.dataset.screen }); break;
      case "home": go({ screen: "home" }); break;
      case "filter": S.state.filter = el.dataset.key; render(); break;
      case "pick-game": go({ screen: "new", gameId: el.dataset.id }); break;

      case "new-custom": go({ screen: "custom" }); break;
      case "edit-custom": go({ screen: "custom", customId: el.dataset.id }); break;
      case "custom-set": {
        readCustomForm();
        const { field, value } = el.dataset;
        if (field === "team") scratch.custom.team = value === "team";
        else if (field === "high") scratch.custom.high = value === "high";
        else scratch.custom[field] = value;
        // Le compte à rebours impose son sens de victoire et un objectif d'où
        // partir : on le pose ici pour que l'écran le montre tout de suite.
        // Changer de moteur change l'ordre de grandeur de l'objectif : 501 à
        // retrancher, 3 manches à gagner. Reproposer 500 manches n'aiderait
        // personne — mais un objectif déjà plausible n'est pas touché.
        if (field === "engine") {
          const t = scratch.custom.target;
          if (value === "countdown" && (t === 0 || t < 100)) scratch.custom.target = 501;
          if (value === "manche" && t > 21) scratch.custom.target = 3;
          if (value === "cumul" && t > 0 && t < 21) scratch.custom.target = 500;
        }
        if (scratch.custom.engine === "countdown") {
          scratch.custom.high = false;
          if (!scratch.custom.target) scratch.custom.target = 501;
        }
        render();
        break;
      }
      case "custom-target": {
        readCustomForm();
        const step = Number(el.dataset.delta);
        scratch.custom.target = Math.max(0, Math.min(10000, scratch.custom.target + step));
        render();
        break;
      }
      case "custom-rounds": {
        readCustomForm();
        const next = scratch.custom.roundLimit + Number(el.dataset.delta);
        scratch.custom.roundLimit = Math.max(0, Math.min(99, next));
        render();
        break;
      }
      case "save-custom": {
        readCustomForm();
        const errors = customGameErrors(scratch.custom, S.state.customGames);
        if (errors.length) { scratch.customErrors = errors; render(); break; }
        const saved = S.saveCustomGame(scratch.custom);
        toast("Jeu enregistré.");
        go({ screen: "new", gameId: saved.id });
        break;
      }
      case "del-custom": {
        if (!confirm("Supprimer ce jeu ? Les parties déjà jouées avec lui sont conservées.")) break;
        S.deleteCustomGame(el.dataset.id);
        if (S.state.filter === "perso" && !S.state.customGames.length) S.state.filter = "all";
        go({ screen: "home" });
        break;
      }
      case "open-session": go({ screen: "score", id: el.dataset.id }); break;

      case "rules": {
        const g = S.gameById(view.gameId);
        openSheet(`Règles · ${g.name}`, g.rules);
        break;
      }
      case "close-sheet": document.getElementById("sheet").close(); break;

      case "cycle": {
        const g = S.gameById(view.gameId);
        const id = el.dataset.id;
        const cur = scratch.assign[id] ?? 0;
        scratch.assign[id] = cur >= (g.team ? 2 : 1) ? 0 : cur + 1;
        render();
        break;
      }
      case "target": {
        scratch.target = Math.max(0, Math.min(10000, scratch.target + Number(el.dataset.delta)));
        render();
        break;
      }
      case "quick-add": {
        const input = document.getElementById("quick-player");
        const name = input.value.trim();
        if (name) { S.addPlayer(name); render(); }
        break;
      }
      case "start": {
        const g = S.gameById(view.gameId);
        const a = scratch.assign;
        let entrants;
        if (g.team) {
          const t1 = S.state.players.filter((p) => a[p.id] === 1);
          const t2 = S.state.players.filter((p) => a[p.id] === 2);
          entrants = [
            { name: t1.map((p) => p.name).join(" + "), colorIndex: 0, playerIds: t1.map((p) => p.id) },
            { name: t2.map((p) => p.name).join(" + "), colorIndex: 3, playerIds: t2.map((p) => p.id) },
          ];
        } else {
          entrants = S.state.players.filter((p) => a[p.id] === 1)
            .map((p) => ({ name: p.name, colorIndex: p.colorIndex, playerIds: [p.id] }));
        }
        const created = S.createSession(g, entrants, scratch.target);
        go({ screen: "score", id: created.id });
        break;
      }

      case "validate-generic": {
        S.addRound(session, scratch.inputs.map((v) => parseInt(v, 10) || 0));
        scratch.inputs = null;
        render();
        break;
      }
      case "phase-done": {
        const i = Number(el.dataset.i);
        scratch.phaseDone[i] = !scratch.phaseDone[i];
        render();
        break;
      }
      case "validate-phase": {
        S.addPhaseRound(session, scratch.inputs.map((v) => parseInt(v, 10) || 0), scratch.phaseDone);
        scratch.inputs = null;
        scratch.phaseDone = null;
        render();
        break;
      }
      case "payoo-fill": {
        const i = payooFillIndex(scratch.inputs, scratch.entryFocus);
        const others = scratch.inputs.reduce((a, v, j) => a + (j === i ? 0 : parseInt(v, 10) || 0), 0);
        scratch.inputs[i] = String(Math.max(0, E.PAYOO_ROUND_TOTAL - others));
        render();
        break;
      }
      case "payoo-validate": {
        const values = scratch.inputs.map((v) => parseInt(v, 10) || 0);
        if (values.reduce((a, b) => a + b, 0) !== E.PAYOO_ROUND_TOTAL) return;
        S.addRound(session, values);
        scratch.inputs = null;
        scratch.entryFocus = null;
        render();
        break;
      }
      case "del-round": S.deleteRound(session, Number(el.dataset.i)); render(); break;
      case "undo": S.undoRound(session); scratch.note = null; render(); break;
      case "finish": S.finishSession(session); toast("Partie terminée."); render(); break;
      case "reopen": S.reopenSession(session); toast("Partie reprise."); render(); break;

      case "edit-round": openRoundEditor(session, Number(el.dataset.i)); break;
      case "save-round": {
        const dlg = document.getElementById("sheet");
        const deltas = [...dlg.querySelectorAll(".round-edit")]
          .map((input) => parseInt(input.value, 10) || 0);
        S.updateRound(session, Number(el.dataset.i), deltas);
        dlg.close();
        toast("Manche corrigée.");
        render();
        break;
      }

      case "del-session": {
        if (!confirm("Supprimer cette partie ? Elle disparaîtra aussi des statistiques.")) break;
        S.deleteSession(el.dataset.id);
        render();
        break;
      }
      case "replay":
        S.resetSession(session, el.dataset.keep === "1");
        scratch = {};
        render();
        break;

      case "b-taker": scratch.belote.taker = Number(el.dataset.v); render(); break;
      case "b-suit": scratch.belote.suit = el.dataset.v; render(); break;
      case "b-belote": {
        const k = el.dataset.v === "0" ? "b0" : "b1";
        scratch.belote[k] = !scratch.belote[k];
        render();
        break;
      }
      case "b-capot": {
        const v = Number(el.dataset.v);
        const f = scratch.belote;
        if (f.capot === v) { f.capot = null; f.p0 = ""; f.p1 = ""; }
        else { f.capot = v; f.p0 = "0"; f.p1 = "0"; }
        render();
        break;
      }
      case "b-validate": {
        const f = scratch.belote;
        const round = {
          takerTeam: f.taker, suit: f.suit,
          cardPoints: [parseInt(f.p0, 10) || 0, parseInt(f.p1, 10) || 0],
          belote: [f.b0, f.b1], capotTeam: f.capot,
          // Les points en jeu sont inscrits dans la donne : le détail affiché
          // reste celui qui a servi au calcul, même des mois plus tard.
          pending: E.belotePending(session.beloteRounds ?? []),
        };
        session.beloteRounds.push(round);
        S.addRound(session, E.beloteDeltas(round));
        scratch.belote = null;
        render();
        break;
      }

      case "pick-player": scratch.current = Number(el.dataset.i); render(); break;
      case "dart": playTurn(session, E.dartsThrow(session, scratch.current, Number(el.dataset.v))); render(); break;
      case "dart-submit": {
        const value = parseInt(document.getElementById("dart-input").value, 10);
        if (Number.isNaN(value)) return;
        playTurn(session, E.dartsThrow(session, scratch.current, value));
        render();
        break;
      }
      case "molkky": {
        const score = Number(el.dataset.v);
        const before = scratch.current;
        playTurn(session, E.molkkyThrow(session, before, score));
        if (score === 0) {
          session.molkkyMisses[before] += 1;
          if (session.molkkyMisses[before] >= 3) {
            session.molkkyOut[before] = true;
            scratch.note = "Trois ratés — joueur éliminé.";
          }
        } else session.molkkyMisses[before] = 0;
        S.commit();
        render();
        break;
      }

      case "yams-player": scratch.selected = Number(el.dataset.i); render(); break;
      case "yams-fixed": {
        session.yamsGrid[Number(el.dataset.p)][Number(el.dataset.c)] = Number(el.dataset.v);
        if (E.yamsAllFilled(session)) session.manuallyFinished = true;
        S.commit();
        render();
        break;
      }

      case "add-player": {
        const input = document.getElementById("new-player");
        const name = input.value.trim();
        if (name) { S.addPlayer(name); render(); }
        break;
      }
      case "del-player": S.removePlayer(el.dataset.id); render(); break;

      case "sign-apple": auth?.signInApple().catch((e) => toast(e.message)); break;
      case "sign-google": auth?.signInGoogle().catch((e) => toast(e.message)); break;
      case "sign-out":
        (auth ? auth.signOut() : Promise.resolve()).finally(() => { S.signOut(); go({ screen: "home" }); });
        break;
      case "wipe": {
        if (!confirm("Effacer définitivement vos joueurs, vos parties et votre compte ?")) return;
        S.deleteEverything().finally(() => { toast("Données supprimées."); go({ screen: "home" }); });
        break;
      }

      case "share": {
        const text = el.dataset.text;
        if (navigator.share) navigator.share({ text }).catch(() => {});
        else navigator.clipboard?.writeText(text).then(() => toast("Résultat copié."));
        break;
      }
    }
  };

  root.addEventListener("click", onClick);
  document.getElementById("sheet").addEventListener("click", onClick);

  // Retenir la case de saisie active : cliquer sur « Compléter » lui fait perdre
  // le focus avant que l'action ne s'exécute.
  root.addEventListener("focusin", (ev) => {
    if (ev.target.classList?.contains("entry")) scratch.entryFocus = Number(ev.target.dataset.i);
  });

  root.addEventListener("input", (ev) => {
    const el = ev.target;
    const session = currentSession();

    if (el.classList.contains("entry")) {
      scratch.inputs[Number(el.dataset.i)] = el.value;
      // Papayoo affiche un compteur vivant : il faut redessiner à la frappe.
      if (session && S.gameById(session.gameId)?.engine === "payoo") renderKeepingFocus();
      return;
    }
    if (el.classList.contains("b-pts")) {
      const t = Number(el.dataset.t);
      const f = scratch.belote;
      if (el.value === "") { f[t === 0 ? "p0" : "p1"] = ""; return; }
      const n = Math.max(0, Math.min(162, parseInt(el.value, 10) || 0));
      f[t === 0 ? "p0" : "p1"] = String(n);
      f[t === 0 ? "p1" : "p0"] = String(162 - n);   // le complément à 162 se déduit
      renderKeepingFocus();
      return;
    }
    if (el.classList.contains("yams-cell")) {
      const p = Number(el.dataset.p), c = Number(el.dataset.c);
      session.yamsGrid[p][c] = el.value.trim() === "" ? -1 : Math.max(0, parseInt(el.value, 10) || 0);
      if (E.yamsAllFilled(session)) { session.manuallyFinished = true; S.commit(); render(); return; }
      S.commit();
    }
  });

  root.addEventListener("change", (ev) => {
    // Changer de joueur remet les deux autres filtres à zéro : ses jeux et ses
    // coéquipiers ne sont pas ceux du précédent, et garder la sélection
    // afficherait « aucune partie » sans raison apparente.
    if (ev.target.id === "stat-player") {
      scratch.statPlayer = ev.target.value;
      scratch.statGame = "all";
      scratch.statMate = "all";
      render();
    }
    if (ev.target.id === "stat-game") { scratch.statGame = ev.target.value; render(); }
    if (ev.target.id === "stat-mate") { scratch.statMate = ev.target.value; render(); }
    if (ev.target.id === "theme-select") S.setTheme(ev.target.value);
  });

  root.addEventListener("keydown", (ev) => {
    if (ev.key !== "Enter") return;
    const id = ev.target.id;
    if (id === "dart-input") {
      const value = parseInt(ev.target.value, 10);
      if (!Number.isNaN(value)) { playTurn(currentSession(), E.dartsThrow(currentSession(), scratch.current, value)); render(); }
    }
    if (id === "new-player" || id === "quick-player") {
      const name = ev.target.value.trim();
      if (name) { S.addPlayer(name); render(); }
    }
  });
}

/** Le rendu remplace tout : on remet le curseur là où il était. */
function renderKeepingFocus() {
  const active = document.activeElement;
  const key = active?.id || (active?.classList.contains("entry") ? `entry-${active.dataset.i}` : null);
  const start = active?.selectionStart, end = active?.selectionEnd;
  render();
  if (!key) return;
  const back = key.startsWith("entry-")
    ? document.querySelector(`.entry[data-i="${key.slice(6)}"]`)
    : document.getElementById(key);
  if (!back) return;
  back.focus();
  try { back.setSelectionRange(start, end); } catch { /* input[type=number] refuse */ }
}
