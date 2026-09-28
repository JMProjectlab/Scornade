// Tests des jeux personnalisés.
//
// À lancer avec `node --test tests/`. Ils portent sur `customgames.js` — la
// mise en forme et la validation d'un jeu créé dans l'application — et sur son
// branchement dans le store. Le même contrat vaut côté iOS (`CustomGame` dans
// Models.swift) : une règle corrigée ici doit l'être là-bas.

import test from "node:test";
import assert from "node:assert/strict";
import * as CG from "../docs/assets/customgames.js";
import * as S from "../docs/assets/store.js";
import * as E from "../docs/assets/engine.js";
import { glyph } from "../docs/assets/data.js";

test("un identifiant personnalisé se reconnaît à son préfixe", () => {
  assert.equal(CG.isCustomGame(CG.newCustomGameId()), true);
  assert.equal(CG.isCustomGame("belote"), false);
  assert.equal(CG.isCustomGame(undefined), false);
});

test("la mise en forme borne au lieu de refuser", () => {
  const g = CG.normalizeCustomGame({
    name: "   Belote de mon grand-père   ",
    engine: "moteur-inventé",
    symbol: "licorne",
    cat: "inconnue",
    target: 99999,
    roundLimit: -4,
    rules: "  à jouer à quatre  ",
  });
  assert.equal(g.name, "Belote de mon grand-père");
  assert.equal(g.engine, "cumul");        // moteur inconnu : on retombe sur le générique
  assert.equal(g.symbol, "star");
  assert.equal(g.cat, "perso");
  assert.equal(g.target, 10000);
  assert.equal(g.roundLimit, 0);
  assert.equal(g.rules, "à jouer à quatre");
  assert.equal(CG.isCustomGame(g.id), true);
});

test("un nom trop long est coupé, pas rejeté", () => {
  const g = CG.normalizeCustomGame({ name: "x".repeat(120) });
  assert.equal(g.name.length, 40);
});

test("le compte à rebours impose son sens de victoire et un objectif", () => {
  const g = CG.normalizeCustomGame({ name: "501 maison", engine: "countdown", target: 0, high: true });
  assert.equal(g.high, false, "descendre à zéro, c'est le plus petit total qui gagne");
  assert.equal(g.target, 500, "sans objectif, il n'y aurait nulle part où descendre");
});

test("un identifiant existant est conservé — modifier n'est pas recréer", () => {
  const id = CG.newCustomGameId();
  assert.equal(CG.normalizeCustomGame({ id, name: "A" }).id, id);
  assert.notEqual(CG.normalizeCustomGame({ id: "belote", name: "A" }).id, "belote");
});

test("ce qui bloque l'enregistrement est dit, et rien d'autre", () => {
  assert.deepEqual(CG.customGameErrors({ name: "  " }), ["Donnez un nom au jeu."]);
  assert.deepEqual(CG.customGameErrors({ name: "Jeu du roi" }), []);

  const mine = [CG.normalizeCustomGame({ name: "Jeu du roi" })];
  assert.equal(CG.customGameErrors({ name: "jeu du roi" }, mine).length, 1,
    "deux jeux du même nom seraient indiscernables dans la grille");
  assert.deepEqual(CG.customGameErrors({ ...mine[0], name: "Jeu du roi" }, mine), [],
    "se renommer soi-même à l'identique n'est pas un doublon");

  assert.equal(CG.customGameErrors({ name: "Belle", engine: "manche", target: 0 }).length, 1);
  assert.deepEqual(CG.customGameErrors({ name: "Belle", engine: "manche", target: 3 }), []);
  assert.deepEqual(CG.customGameErrors({ name: "Belle", engine: "manche", target: 0, roundLimit: 5 }), []);
});

test("les manches gagnées empruntent le moteur cumulatif", () => {
  const g = CG.toGame({ name: "Belle", engine: "manche", target: 3, high: true });
  assert.equal(g.engine, "cumul");
  assert.equal(g.custom, true);
  assert.equal(CG.toGame({ name: "501", engine: "countdown" }).engine, "countdown");
});

test("un jeu personnalisé se termine comme les autres", () => {
  const g = CG.toGame({ name: "Belle", engine: "manche", target: 3, high: true });
  const s = {
    entrants: [{ name: "A" }, { name: "B" }],
    rounds: [[1, 0], [1, 0]],
    direction: g.engine === "countdown" ? "countdown" : "accumulate",
    target: g.target,
    higherWins: g.high,
    roundLimit: g.roundLimit,
    manuallyFinished: false,
  };
  assert.equal(E.isFinished(s), false);
  s.rounds.push([1, 0]);
  assert.equal(E.isFinished(s), true);
  assert.equal(E.winnerIndex(s), 0);
});

test("un compte à rebours personnalisé descend jusqu'à zéro", () => {
  const g = CG.toGame({ name: "301 maison", engine: "countdown", target: 301 });
  const s = {
    entrants: [{ name: "A" }, { name: "B" }],
    rounds: [[180, 60], [121, 40]],
    direction: "countdown",
    target: g.target,
    higherWins: g.high,
    roundLimit: 0,
    manuallyFinished: false,
  };
  assert.equal(E.total(s, 0), 0);
  assert.equal(E.isFinished(s), true);
  assert.equal(E.winnerIndex(s), 0);
});

test("le pictogramme d'un jeu personnalisé vient de son symbole", () => {
  const svg = glyph("custom-1234", 22, "trophy");
  assert.match(svg, /<svg/);
  assert.notEqual(svg, glyph("custom-1234", 22, "dice"));
  assert.match(glyph("custom-1234", 22), /<svg[^>]*><\/svg>/, "sans symbole, un cadre vide");
});

// --- branchement dans le store -------------------------------------------

test("le store range les jeux personnalisés après le catalogue", () => {
  S.load();
  const before = S.allGames().length;

  const saved = S.saveCustomGame({ name: "Tarot maison", symbol: "cards", target: 700 });
  assert.equal(S.allGames().length, before + 1);
  assert.equal(S.allGames().at(-1).id, saved.id, "les jeux livrés ne changent pas de place");
  assert.equal(S.gameById(saved.id).name, "Tarot maison");
  assert.equal(S.gameById("belote").name, "Belote", "le catalogue embarqué répond toujours");

  S.saveCustomGame({ ...saved, name: "Tarot du dimanche" });
  assert.equal(S.allGames().length, before + 1, "enregistrer deux fois ne duplique pas");
  assert.equal(S.gameById(saved.id).name, "Tarot du dimanche");

  S.deleteCustomGame(saved.id);
  assert.equal(S.allGames().length, before);
  assert.equal(S.gameById(saved.id), undefined);
});

test("une partie garde le nom et le symbole du jeu supprimé", () => {
  S.load();
  const g = CG.toGame(S.saveCustomGame({ name: "Jeu du grenier", symbol: "flag" }));
  const session = S.createSession(g, [
    { name: "A", colorIndex: 0, playerIds: [] },
    { name: "B", colorIndex: 1, playerIds: [] },
  ], g.target);

  S.deleteCustomGame(g.id);
  assert.equal(S.gameById(session.gameId), undefined, "le jeu n'est plus au catalogue");
  assert.equal(session.gameName, "Jeu du grenier");
  assert.equal(session.symbol, "flag", "l'historique reste lisible");
  S.deleteSession(session.id);
});
