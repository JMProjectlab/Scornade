// Tests du droit d'accès aux fonctionnalités payantes.
//
// La règle est simple et elle est écrite une fois : le site ne vend pas, il
// reconnaît. Ces tests disent ce que « reconnaître » veut dire, y compris dans
// les cas qui coincent — sans compte, et pour un jeu créé avant l'achat.

import test from "node:test";
import assert from "node:assert/strict";
import * as Ent from "../docs/assets/entitlements.js";

const bought = [{ id: Ent.CREATOR_PRODUCT_ID, purchasedAt: "2026-09-13T10:00:00Z" }];

test("sans achat, on ne crée pas de nouveau jeu", () => {
  assert.equal(Ent.ownsCreator({ purchases: [] }), false);
  assert.equal(Ent.canCreateCustomGame({ purchases: [] }), false);
  assert.equal(Ent.canCreateCustomGame({}), false, "un état vide ne débloque rien");
});

test("l'achat du créateur ouvre la création", () => {
  assert.equal(Ent.ownsCreator({ purchases: bought }), true);
  assert.equal(Ent.canCreateCustomGame({ purchases: bought }), true);
});

test("un autre achat ne débloque pas le créateur", () => {
  const other = [{ id: "com.jmprojectlab.scornade.autre" }];
  assert.equal(Ent.ownsCreator({ purchases: other }), false);
});

test("un jeu déjà créé reste modifiable sans achat", () => {
  const state = { purchases: [], customGames: [{ id: "custom-abc", name: "Belote maison" }] };
  assert.equal(Ent.canEditCustomGame(state, "custom-abc"), true,
    "le créateur a été livré gratuit : on ne reprend pas ce qui a été donné");
  assert.equal(Ent.canEditCustomGame(state, "custom-inconnu"), false);
  assert.equal(Ent.canCreateCustomGame(state), false, "mais en créer un de plus, non");
});

test("la raison du verrou distingue le visiteur sans compte de l'acheteur potentiel", () => {
  assert.equal(Ent.creatorLockReason({ purchases: bought }), null);
  assert.equal(Ent.creatorLockReason({ purchases: [], user: null }), "connect");
  assert.equal(Ent.creatorLockReason({ purchases: [], user: { mode: "guest" } }), "connect",
    "sans compte, il n'y a rien où lire un achat");
  assert.equal(Ent.creatorLockReason({ purchases: [], user: { mode: "apple" } }), "buy");
});

test("un achat illisible est ignoré plutôt que de tout faire tomber", () => {
  assert.equal(Ent.ownsCreator({ purchases: [null, undefined, {}, "texte"] }), false);
});
