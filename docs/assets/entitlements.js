// Droit d'accès aux fonctionnalités payantes.
//
// **Le site ne vend rien.** L'achat se fait dans l'application iOS, par
// StoreKit — seul canal autorisé par la règle 3.1.1 d'Apple, et seule chaîne
// commerciale que l'atelier veut monter. Le site, lui, se contente de
// reconnaître un achat déjà fait : l'app écrit le droit d'accès dans le compte,
// le site le lit.
//
// Conséquence assumée : un utilisateur peut techniquement s'accorder ce droit
// lui-même, puisque les règles Firestore l'autorisent à écrire sous son propre
// identifiant. Le fermer vraiment demanderait un serveur. À ce prix-là, le
// contournement coûte plus cher que l'achat — voir la note « Un verrou posé
// côté client est une convention, pas une sécurité ».

/** L'identifiant du produit, tel qu'il sera déclaré dans App Store Connect. */
export const CREATOR_PRODUCT_ID = "com.jmprojectlab.scornade.creator";

/** L'utilisateur a-t-il acheté le créateur de jeu ? */
export function ownsCreator(state) {
  return (state?.purchases ?? []).some((p) => p?.id === CREATOR_PRODUCT_ID);
}

/**
 * Peut-on créer un **nouveau** jeu personnalisé ?
 *
 * Sans compte, la question ne se pose pas : il n'y a rien où lire un achat, et
 * rien où le restaurer. C'est l'autre face de « Continuer sans compte » — tout
 * reste sur l'appareil, y compris ce qui manque.
 */
export function canCreateCustomGame(state) {
  return ownsCreator(state);
}

/**
 * Peut-on modifier un jeu déjà créé ?
 *
 * Oui, toujours. Le créateur a été livré gratuit : reprendre l'accès à ce qui
 * existe déjà reviendrait à retirer ce qui avait été donné. On facture ce qu'on
 * ajoute, jamais ce qu'on a promis.
 */
export function canEditCustomGame(state, gameId) {
  return (state?.customGames ?? []).some((g) => g.id === gameId);
}

/** Ce qu'il faut dire à l'utilisateur, selon là où il en est. */
export function creatorLockReason(state) {
  if (ownsCreator(state)) return null;
  if (!state?.user || state.user.mode === "guest") {
    return "connect";      // pas de compte : rien à lire, rien à restaurer
  }
  return "buy";            // compte connu, achat absent
}
