// Tests du moteur de score du site.
//
// À lancer avec `node --test tests/engine.test.mjs`. Ils portent sur
// `docs/assets/engine.js`, qui calcule la même chose que `Models.swift` :
// une règle corrigée d'un côté doit l'être de l'autre, et ces tests disent
// ce que le côté web est censé faire.

import test from "node:test";
import assert from "node:assert/strict";
import * as E from "../docs/assets/engine.js";
import { GAMES, gameById, glyph } from "../docs/assets/data.js";

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

test("chaque jeu du catalogue a des règles et un pictogramme", () => {
  for (const g of GAMES) {
    assert.ok(g.rules?.length > 40, `${g.id} n'a pas de règles`);
    assert.ok(glyph(g.id, 22).includes("<"), `${g.id} n'a pas de pictogramme`);
  }
});

test("les trois derniers jeux ajoutés sont bien configurés", () => {
  assert.equal(gameById("phase10").engine, "phase");
  assert.equal(gameById("cinqrois").roundLimit, 11);
  assert.equal(gameById("dekal").target, 100);
  for (const id of ["dekal", "phase10", "cinqrois"]) {
    assert.equal(gameById(id).high, false, `${id} se gagne au plus petit total`);
  }
});

// --- Mölkky : les ratés ---------------------------------------------------

test("Mölkky — trois ratés d'affilée éliminent, un lancer réussi remet à zéro", () => {
  const s = session({ molkkyMisses: [0, 0, 0], molkkyOut: [false, false, false] });
  assert.equal(E.molkkyMiss(s, 0, true), false);
  assert.equal(E.molkkyMiss(s, 0, true), false);
  assert.equal(E.molkkyMiss(s, 0, true), true, "le troisième raté élimine");
  assert.deepEqual(s.molkkyOut, [true, false, false]);

  E.molkkyMiss(s, 1, true);
  E.molkkyMiss(s, 1, true);
  E.molkkyMiss(s, 1, false);
  E.molkkyMiss(s, 1, true);
  assert.equal(s.molkkyOut[1], false, "le compteur repart de zéro après un lancer réussi");
});

test("Mölkky — une partie venue de l'app iOS n'a pas les compteurs, et ne doit pas planter", () => {
  const s = session();                       // ni molkkyMisses ni molkkyOut
  assert.doesNotThrow(() => E.molkkyMiss(s, 0, true));
  assert.deepEqual(s.molkkyMisses, [1, 0, 0]);
  assert.deepEqual(s.molkkyOut, [false, false, false]);
});

test("Mölkky — un joueur déjà éliminé ne l'est pas une seconde fois", () => {
  const s = session({ molkkyMisses: [3, 0, 0], molkkyOut: [true, false, false] });
  assert.equal(E.molkkyMiss(s, 0, true), false, "pas de second message d'élimination");
  assert.equal(s.molkkyOut[0], true);
});
