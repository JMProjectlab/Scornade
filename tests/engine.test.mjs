// Tests du moteur de score du site.
//
// À lancer avec `node --test tests/engine.test.mjs`. Ils portent sur
// `docs/assets/engine.js`, qui calcule la même chose que `Models.swift` :
// une règle corrigée d'un côté doit l'être de l'autre, et ces tests disent
// ce que le côté web est censé faire.

import test from "node:test";
import assert from "node:assert/strict";
import * as E from "../docs/assets/engine.js";
import { GAMES, gameById, glyph, applyCatalogOverrides } from "../docs/assets/data.js";

const session = (over = {}) => ({
  entrants: [{ name: "A" }, { name: "B" }, { name: "C" }],
  rounds: [],
  direction: "accumulate",
  target: 0,
  higherWins: false,
  manuallyFinished: false,
  ...over,
});

// --- Phase 10 -------------------------------------------------------------

test("Phase 10 — la phase se déduit des manches validées", () => {
  const s = session({ phaseRounds: [] });
  assert.equal(E.phaseOf(s, 0), 1);
  assert.equal(E.isFinished(s), false);

  for (let r = 0; r < 9; r++) {
    s.phaseRounds.push([true, r < 8, false]);
    s.rounds.push([0, 5, 20]);
  }
  assert.equal(E.phaseOf(s, 0), 10);
  assert.equal(E.phaseOf(s, 1), 9);
  assert.equal(E.phaseOf(s, 2), 1, "qui ne passe jamais reste en phase 1");
  assert.equal(E.isFinished(s), false);
});

test("Phase 10 — c'est la dixième phase qui gagne, pas le total", () => {
  const s = session({ phaseRounds: [] });
  for (let r = 0; r < 10; r++) {
    s.phaseRounds.push([true, false, false]);
    s.rounds.push([50, 0, 0]);
  }
  assert.equal(E.phaseOf(s, 0), 11);
  assert.equal(E.isFinished(s), true);
  assert.equal(E.winnerIndex(s), 0, "A gagne malgré 500 points de pénalité");
});

test("Phase 10 — à égalité de phases, le plus petit total départage", () => {
  const s = session({ phaseRounds: [] });
  for (let r = 0; r < 10; r++) {
    s.phaseRounds.push([true, true, false]);
    s.rounds.push([10, 3, 0]);
  }
  assert.equal(E.winnerIndex(s), 1);
});

test("Phase 10 — annuler une manche rend sa phase", () => {
  const s = session({ phaseRounds: [] });
  for (let r = 0; r < 10; r++) {
    s.phaseRounds.push([true, false, false]);
    s.rounds.push([5, 5, 5]);
  }
  assert.equal(E.isFinished(s), true);

  s.phaseRounds.pop();
  s.rounds.pop();
  assert.equal(E.phaseOf(s, 0), 10);
  assert.equal(E.isFinished(s), false, "la partie repart");
});

// --- Les Cinq Rois --------------------------------------------------------

test("Les Cinq Rois — la partie tient en onze manches", () => {
  const s = session({ roundLimit: 11 });
  for (let r = 0; r < 10; r++) s.rounds.push([5, 8, 2]);
  assert.equal(E.isFinished(s), false);

  s.rounds.push([5, 8, 2]);
  assert.equal(E.isFinished(s), true);
  assert.equal(E.winnerIndex(s), 2, "le plus petit total gagne");
});

// --- Non-régression -------------------------------------------------------

test("Dékal — la partie s'arrête à 100 et le plus bas gagne", () => {
  const s = session({ target: 100, rounds: [[40, 10, 5], [70, 20, 8]] });
  assert.equal(E.isFinished(s), true);
  assert.equal(E.winnerIndex(s), 2);
});

test("un jeu à objectif ordinaire n'est pas affecté", () => {
  const s = session({ target: 500, higherWins: true, rounds: [[100, 20, 5]] });
  assert.equal(E.isFinished(s), false);
  assert.equal(E.winnerIndex(s), null);
});

test("les fléchettes comptent toujours à rebours", () => {
  const s = session({ direction: "countdown", target: 501, rounds: [[501, 60, 40]] });
  assert.equal(E.total(s, 0), 0);
  assert.equal(E.isFinished(s), true);
  assert.equal(E.winnerIndex(s), 0);
});

// --- Catalogue ------------------------------------------------------------

test("chaque jeu du catalogue a des règles et un pictogramme qui lui est propre", () => {
  // Le repli est le même pour tous : le comparer suffit à distinguer un jeu
  // réellement dessiné d'un jeu qui retombe sur le pictogramme par défaut.
  const fallback = glyph("jeu-qui-n-existe-pas", 22);
  for (const g of GAMES) {
    assert.ok(g.rules?.length > 40, `${g.id} n'a pas de règles`);
    assert.notEqual(glyph(g.id, 22), fallback, `${g.id} n'a pas de pictogramme`);
  }
});

test("un jeu inconnu reçoit un pictogramme par défaut, pas un SVG vide", () => {
  // Un jeu venu du catalogue distant, ou une partie synchronisée depuis une
  // version plus récente : il faut dessiner quelque chose, sans quoi la case
  // vide passe pour un défaut d'affichage.
  const svg = glyph("jeu-qui-n-existe-pas", 22);
  assert.match(svg, /^<svg /);
  assert.ok(svg.includes("currentColor"), "le repli ne dessine rien");
  assert.ok(!/<svg[^>]*><\/svg>/.test(svg), "le repli est un SVG vide");
});

test("gameById ne connaît pas un jeu absent du catalogue", () => {
  // Le contrat sur lequel s'appuie le repli de l'écran de score : c'est bien
  // `undefined` qu'il faut savoir rattraper, pas une exception.
  assert.equal(gameById("jeu-qui-n-existe-pas"), undefined);
});

test("les trois derniers jeux ajoutés sont bien configurés", () => {
  assert.equal(gameById("phase10").engine, "phase");
  assert.equal(gameById("cinqrois").roundLimit, 11);
  assert.equal(gameById("dekal").target, 100);
  for (const id of ["dekal", "phase10", "cinqrois"]) {
    assert.equal(gameById(id).high, false, `${id} se gagne au plus petit total`);
  }
});

// --- Catalogue distant : ajouter un jeu -----------------------------------
//
// `applyCatalogOverrides` modifie `GAMES` en place. Chaque test remet donc le
// catalogue dans son état livré en supprimant ce qu'il a ajouté.

const shippedIds = GAMES.map((g) => g.id);
const resetCatalog = () => applyCatalogOverrides({});

const validGame = {
  name: "Triominos",
  engine: "points",
  category: "societe",
  defaultTarget: 400,
  higherWins: true,
  rules: "Des tuiles triangulaires à assembler.",
};

test("un identifiant inconnu avec un moteur générique ajoute un jeu", (t) => {
  t.after(resetCatalog);
  assert.equal(applyCatalogOverrides({ triominos: validGame }), 1);

  const g = gameById("triominos");
  assert.ok(g, "le jeu n'a pas été ajouté");
  assert.equal(g.name, "Triominos");
  assert.equal(g.engine, "cumul");
  assert.equal(g.target, 400);
  assert.equal(g.cat, "societe");
  assert.equal(g.roundLimit, 0);
  // Il se compte comme n'importe quel jeu générique.
  const s = session({ entrants: [{ name: "A" }, { name: "B" }], target: 400, higherWins: true });
  s.rounds = [[400, 10]];
  assert.equal(E.isFinished(s), true);
  assert.equal(E.winnerIndex(s), 0);
});

test("les moteurs à écran dédié ne sont pas ajoutables à distance", (t) => {
  t.after(resetCatalog);
  for (const engine of ["belote", "payoo", "grid", "phase", "molkky", "cumul", ""]) {
    assert.equal(
      applyCatalogOverrides({ essai: { ...validGame, engine } }), 0,
      `le moteur ${engine || "(vide)"} n'aurait pas dû passer`,
    );
    assert.equal(gameById("essai"), undefined);
  }
});

test("les trois moteurs génériques sont acceptés", (t) => {
  t.after(resetCatalog);
  const attendu = { points: "cumul", countdown: "countdown", rounds: "cumul" };
  for (const [distant, local] of Object.entries(attendu)) {
    applyCatalogOverrides({ [`jeu-${distant}`]: { ...validGame, engine: distant } });
    assert.equal(gameById(`jeu-${distant}`)?.engine, local, `moteur ${distant}`);
  }
});

test("un document incomplet ou mal formé n'ajoute rien", (t) => {
  t.after(resetCatalog);
  const refuses = {
    "sans-nom": { engine: "points" },
    "nom-vide": { engine: "points", name: "   " },
    "sans-moteur": { name: "Sans moteur" },
    "moteur-inconnu": { name: "Inconnu", engine: "quantique" },
    "Majuscules": { ...validGame },
    "espace interdit": { ...validGame },
    "accentué": { ...validGame },
  };
  for (const [id, fields] of Object.entries(refuses)) {
    assert.equal(applyCatalogOverrides({ [id]: fields }), 0, `${id} aurait dû être refusé`);
    assert.equal(gameById(id), undefined, `${id} a été ajouté`);
  }
  assert.deepEqual(GAMES.map((g) => g.id), shippedIds, "le catalogue livré a bougé");
});

test("les valeurs manquantes reçoivent un défaut jouable", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({ minimal: { name: "Minimal", engine: "points" } });

  const g = gameById("minimal");
  assert.equal(g.cat, "societe", "catégorie par défaut");
  assert.equal(g.target, 0);
  assert.equal(g.high, true, "le plus haut total gagne par défaut");
  assert.equal(g.team, false);
  assert.equal(g.rules, "");
  // Une catégorie inconnue masquerait le jeu sous tous les onglets sauf « Tous ».
  applyCatalogOverrides({ minimal: { name: "Minimal", engine: "points", category: "échecs" } });
  assert.equal(gameById("minimal").cat, "societe");
});

test("un jeu ajouté disparaît quand son document est supprimé", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({ triominos: validGame });
  assert.ok(gameById("triominos"));

  assert.equal(applyCatalogOverrides({}), 1, "le retrait n'a pas été compté");
  assert.equal(gameById("triominos"), undefined);
  assert.deepEqual(GAMES.map((g) => g.id), shippedIds);
});

test("les jeux ajoutés viennent après les jeux livrés, classés par nom", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({
    zanzibar: { ...validGame, name: "Zanzibar" },
    aluette: { ...validGame, name: "Aluette" },
  });
  assert.deepEqual(GAMES.slice(shippedIds.length).map((g) => g.name), ["Aluette", "Zanzibar"]);
  assert.deepEqual(GAMES.slice(0, shippedIds.length).map((g) => g.id), shippedIds);
});

test("appliquer deux fois le même catalogue ne duplique pas le jeu", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({ triominos: validGame });
  applyCatalogOverrides({ triominos: validGame });
  assert.equal(GAMES.filter((g) => g.id === "triominos").length, 1);
});

test("un jeu ajouté reste corrigeable comme un jeu livré", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({ triominos: validGame });
  applyCatalogOverrides({ triominos: { ...validGame, name: "Triominos Deluxe", defaultTarget: 500 } });

  const g = gameById("triominos");
  assert.equal(g.name, "Triominos Deluxe");
  assert.equal(g.target, 500);
});

test("un jeu livré ne peut pas changer de moteur à distance", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({ belote: { engine: "points", higherWins: false, isTeamGame: false } });

  const g = gameById("belote");
  assert.equal(g.engine, "belote", "le moteur d'un jeu livré a changé");
  assert.equal(g.high, true);
  assert.equal(g.team, true);
});

test("une correction retirée rend au jeu sa valeur livrée", (t) => {
  t.after(resetCatalog);
  const livre = gameById("uno").name;
  applyCatalogOverrides({ uno: { name: "Uno Flip" } });
  assert.equal(gameById("uno").name, "Uno Flip");

  // Le document supprimé de la console : on repart du catalogue livré, on ne
  // garde pas la dernière correction reçue.
  assert.equal(applyCatalogOverrides({}), 1);
  assert.equal(gameById("uno").name, livre);
});

test("le moteur d'un jeu ajouté suit son document", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({ triominos: { ...validGame, engine: "points" } });
  assert.equal(gameById("triominos").engine, "cumul");

  // Contrairement à un jeu livré, un jeu ajouté est reconstruit en entier à
  // chaque application : son moteur n'est pas figé dans le code.
  applyCatalogOverrides({ triominos: { ...validGame, engine: "countdown", higherWins: false } });
  assert.equal(gameById("triominos").engine, "countdown");
  assert.equal(gameById("triominos").high, false);
});

test("un jeu ajouté dont le document devient invalide disparaît", (t) => {
  t.after(resetCatalog);
  applyCatalogOverrides({ triominos: validGame });
  assert.ok(gameById("triominos"));

  applyCatalogOverrides({ triominos: { ...validGame, engine: "quantique" } });
  assert.equal(gameById("triominos"), undefined);
  assert.deepEqual(GAMES.map((g) => g.id), shippedIds);
});
