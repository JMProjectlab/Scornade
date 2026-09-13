// Catalogue des jeux — miroir de GameCatalog.swift.
// Les identifiants doivent rester identiques à ceux de l'app iOS : ce sont eux
// qui figurent dans les documents Firestore partagés entre les deux clients.

export const GAMES = [
  { id: "belote", name: "Belote", cat: "cartes", engine: "belote", team: true, target: 501, high: true,
    rules: "Jeu de plis à quatre, en deux équipes, avec 32 cartes et un atout choisi à chaque donne.\n\nÀ l'atout, l'ordre change : Valet 20 points, 9 14, As 11, 10 10, Roi 4, Dame 3, le 8 et le 7 rien. Dans les autres couleurs : As 11, 10 10, Roi 4, Dame 3, Valet 2, le reste rien. Les cartes totalisent 152 points, plus 10 pour le dernier pli — le dix de der — soit 162 points par donne.\n\nLe camp qui prend s'engage à faire au moins 82 points, c'est-à-dire plus de la moitié. S'il y parvient, chaque camp marque ce qu'il a ramassé. Sinon il est dedans, et les 162 points vont entièrement à la défense.\n\nÀ 81 partout, il y a litige : le preneur ne marque rien et ses 81 points sont remis en jeu, tandis que la défense encaisse les siens. Les points remis en jeu reviennent au camp qui remporte la donne suivante — deux litiges de suite en mettent donc 162 en jeu.\n\nLa belote-rebelote — Roi et Dame d'atout dans la même main — rapporte 20 points à son camp, qui les conserve même contrat manqué. Le capot, tous les plis pour un seul camp, vaut 252 points.\n\nPremier camp à l'objectif gagne." },
  { id: "coinche", name: "Coinche", cat: "cartes", engine: "cumul", team: true, target: 1000, high: true,
    rules: "La belote, mais l'atout et l'engagement se décident aux enchères. On annonce un nombre de points de 80 à 160, de dix en dix, dans une couleur — ou un capot, voire une générale.\n\nLes 162 points de la donne se comptent comme à la belote : 152 aux cartes, 10 pour le dix de der, et 20 de plus pour la belote-rebelote. Le camp qui prend doit atteindre le contrat annoncé, sans quoi il perd tout et la défense encaisse.\n\nL'adversaire qui juge le contrat intenable peut coincher : l'enjeu double. Le camp coinché peut alors surcoincher, et l'enjeu quadruple.\n\nPremier camp à l'objectif gagne." },
  { id: "tarot", name: "Tarot", cat: "cartes", engine: "cumul", team: false, target: 500, high: true,
    rules: "78 cartes : 21 atouts, l'Excuse, et quatre couleurs de 14 cartes (Roi, Dame, Cavalier, Valet, puis 10 à 1).\n\nLes trois bouts sont le 1 d'atout (le Petit), le 21 et l'Excuse. Ce sont eux qui fixent l'objectif du preneur : 56 points sans bout, 51 avec un, 41 avec deux, 36 avec les trois.\n\nLe preneur joue seul contre tous les autres — à cinq, il appelle un roi et s'associe à celui qui le détient. Quatre contrats, quatre multiplicateurs : Prise ×1, Garde ×2, Garde sans ×4, Garde contre ×6. En Prise et en Garde, le chien est retourné et le preneur fait son écart ; en Garde sans il lui revient sans être vu ; en Garde contre il va à la défense.\n\nScore d'une donne : (25 + écart) × contrat, l'écart étant la différence avec l'objectif. S'y ajoutent le petit au bout (10 × contrat, pour le camp qui remporte la dernière levée avec le Petit) et la poignée (20, 30 ou 40 points, jamais multipliés). Le preneur encaisse ce total autant de fois qu'il a d'adversaires, et chacun d'eux le perd une fois : la somme d'une donne est toujours nulle.\n\nSeuils de poignée : 13, 15 ou 18 atouts à trois joueurs ; 10, 13 ou 15 à quatre ; 8, 10 ou 13 à cinq." },
  { id: "papayoo", name: "Papayoo", cat: "societe", engine: "payoo", team: false, target: 1000, high: false,
    rules: "60 cartes : quatre couleurs numérotées de 1 à 10, sans aucune valeur, qui servent seulement à jouer les plis, et 20 payoos numérotés de 1 à 20.\n\nChaque payoo vaut son numéro en points de pénalité. Avant la donne, un dé (ou une carte tirée au hasard) désigne une couleur : le 7 de cette couleur devient le Papayoo et vaut 40 points à lui seul. Une manche met donc toujours 250 points en jeu — 210 pour les payoos, 40 pour le Papayoo.\n\nCartes distribuées et taille de l'écart, selon le nombre de joueurs :\n• 3 joueurs — 20 cartes, écart de 5\n• 4 joueurs — 15 cartes, écart de 5\n• 5 joueurs — 12 cartes, écart de 4\n• 6 joueurs — 10 cartes, écart de 3\n• 7 joueurs — 8 cartes, écart de 3\n• 8 joueurs — 7 cartes, écart de 3\n\nÀ sept et à huit joueurs, on retire d'abord les 1 des quatre couleurs — jamais un payoo.\n\nChacun choisit son écart et le passe face cachée à son voisin de gauche, avant de regarder celui qu'il reçoit de sa droite. On joue ensuite aux plis : il faut fournir la couleur demandée, sinon on se défausse de ce qu'on veut. Il n'y a pas d'atout, et c'est la plus forte carte de la couleur demandée qui remporte le pli, avec toutes les pénalités qu'il contient.\n\nLe total marqué sur une manche vaut toujours 250. Le moins de points possible gagne." },
  { id: "rami", name: "Rami", cat: "cartes", engine: "cumul", team: false, target: 500, high: false,
    rules: "On forme des combinaisons — suites d'au moins trois cartes de la même couleur, ou brelans et carrés de même valeur — jusqu'à poser toute sa main.\n\nDès qu'un joueur termine, les autres comptent ce qui leur reste : les figures valent 10, l'As 11 lorsqu'il suit le Roi et 1 lorsqu'il ouvre une suite, les autres cartes leur numéro, et le Joker 20 points à la plupart des tables.\n\nCes points s'ajoutent au passif. Le score cumulé le plus bas à l'objectif gagne." },
  { id: "uno", name: "Uno", cat: "societe", engine: "cumul", team: false, target: 500, high: true,
    rules: "Le premier à se défausser de toutes ses cartes remporte la manche et marque ce qui reste dans les mains adverses.\n\nValeurs : les cartes numérotées comptent leur chiffre ; Passe, Inversion et +2 valent 20 points chacune ; Joker et +4 en valent 50.\n\nNe pas annoncer « Uno » avant de poser son avant-dernière carte coûte deux cartes de pénalité si quelqu'un le remarque.\n\nOn joue jusqu'à 500 points, et c'est le score cumulé le plus haut qui gagne." },
  { id: "skyjo", name: "Skyjo", cat: "societe", engine: "cumul", team: false, target: 100, high: false,
    rules: "Chacun a une grille de douze cartes face cachée, dont les valeurs vont de −2 à 12. À son tour, on échange une carte avec la pioche ou la défausse, ou on en retourne une, pour faire baisser son total.\n\nUne colonne de trois cartes identiques est retirée du jeu : elle ne compte plus rien.\n\nLa manche s'arrête dès qu'un joueur a retourné toute sa grille. Tout le monde révèle alors ses cartes et additionne. Attention à qui ferme : il doit avoir le total le plus bas, strictement, faute de quoi son score de manche est doublé.\n\nLa partie s'arrête dès qu'un joueur atteint 100 points. Le plus petit total l'emporte." },
  { id: "scrabble", name: "Scrabble", cat: "societe", engine: "cumul", team: false, target: 0, high: true,
    rules: "Chaque mot posé rapporte la valeur de ses lettres, modifiée par les cases couvertes : lettre compte double ou triple, mot compte double ou triple. Les multiplicateurs de mot s'appliquent après ceux de lettre, et une case ne sert qu'une fois.\n\nPoser ses sept lettres en un seul coup — un scrabble — ajoute 50 points de prime.\n\nEn fin de partie, chacun retranche la valeur des lettres qui lui restent, et celui qui a terminé ajoute la somme de celles des autres. Le total le plus élevé gagne." },
  { id: "flechettes", name: "Fléchettes", cat: "sport", engine: "countdown", team: false, target: 501, high: false,
    rules: "Chaque joueur part de 501 et retranche ce qu'il marque à chaque volée de trois fléchettes. Le double compte deux fois la valeur du secteur, le triple trois fois, le vert extérieur 25 et le rouge central 50.\n\nIl faut tomber exactement à zéro. Une volée qui ferait passer en dessous, ou qui laisserait 1 point, est annulée : c'est le bust, et le score revient à ce qu'il était avant la volée.\n\nScornade compte en sortie simple : arriver à zéro suffit. En compétition on joue en double out, où la dernière fléchette doit se planter dans un double ou dans le rouge central — la saisie ne change pas, c'est à vous de ne valider que les sorties conformes." },
  { id: "petanque", name: "Pétanque", cat: "sport", engine: "cumul", team: true, target: 13, high: true,
    rules: "À chaque mène, l'équipe dont la boule est la plus proche du cochonnet marque un point par boule mieux placée que la meilleure de l'adversaire — donc de 1 à 6 points selon la formation.\n\nOn rejoue jusqu'à ce qu'une équipe atteigne 13 points." },
  { id: "billard", name: "Billard", cat: "sport", engine: "cumul", team: false, target: 5, high: true,
    rules: "Scornade compte les manches gagnées, quelle que soit la variante — 8 américain, 9, ou partie libre.\n\nLe premier au nombre de manches convenu remporte le match." },
  { id: "yams", name: "Yam's", cat: "des", engine: "grid", team: false, target: 0, high: true,
    rules: "Treize catégories à remplir, une par tour. À chaque tour on lance cinq dés, avec deux relances possibles sur les dés de son choix.\n\nSection supérieure — des 1 aux 6 — on marque la somme des dés de la valeur choisie. Si cette section atteint 63 points, elle rapporte 35 points de bonus.\n\nSection inférieure : le brelan et le carré valent la somme des cinq dés, le full 25, la petite suite 30, la grande suite 40, le Yam's 50, et la Chance la somme des dés.\n\nUne catégorie ne se remplit qu'une fois. Quand rien ne convient, il faut en barrer une à zéro. Le plus gros total gagne." },
  { id: "421", name: "421", cat: "des", engine: "cumul", team: false, target: 0, high: false,
    rules: "Trois dés, 21 jetons — 11 seulement à deux joueurs — et deux phases.\n\nLa charge : le pot se vide, et c'est le perdant de chaque coup qui ramasse les jetons. Mieux vaut en prendre le moins possible.\n\nLa décharge : une fois le pot vide, les jetons passent du meilleur au moins bon du coup. Le premier à n'en avoir plus aucun gagne.\n\nValeurs appliquées par l'application : le 421 vaut 10 jetons, le brelan d'as 7, les autres brelans leur numéro — de 6 à 2 — la tierce et la nénette 2, et toute autre combinaison 1. Ces barèmes varient d'une table à l'autre ; ce sont ceux-là que Scornade utilise." },
  { id: "manille", name: "Manille", cat: "cartes", engine: "cumul", team: true, target: 500, high: true,
    rules: "Jeu de plis par équipes de deux, avec 32 cartes.\n\nL'ordre est particulier : le 10 est la carte maîtresse — la manille — suivi de l'As, appelé manillon. La manille vaut 5 points, l'As 4, le Roi 3, la Dame 2, le Valet 1 ; le 9, le 8 et le 7 ne valent rien. Soit 60 points par donne.\n\nCertaines tables ajoutent un point pour le dernier pli. C'est à convenir avant de commencer.\n\nPremier camp à l'objectif gagne." },
  { id: "backgammon", name: "Backgammon", cat: "des", engine: "cumul", team: false, target: 7, high: true,
    rules: "Scornade tient le score du match, pas la partie elle-même.\n\nUne partie gagnée vaut 1 point. Elle en vaut 2 si l'adversaire n'a sorti aucun pion — le gammon — et 3 s'il lui en reste dans votre jan intérieur ou sur la barre — le backgammon. Le videau multiplie ce résultat par la valeur qu'il a atteinte.\n\nPremier au nombre de points convenu remporte le match." },
  { id: "bowling", name: "Bowling", cat: "sport", engine: "cumul", team: false, target: 0, high: true,
    rules: "Dix frames par partie, deux boules par frame. Un spare ajoute les quilles de la boule suivante, un strike celles des deux boules suivantes — d'où un maximum à 300.\n\nSaisissez le score final de chaque joueur, celui qu'affiche la piste. Le plus haut gagne." },
  { id: "poker", name: "Poker", cat: "cartes", engine: "cumul", team: false, target: 0, high: true,
    rules: "Scornade suit le tapis de chaque joueur, pas les mains.\n\nÀ chaque étape, saisissez la variation de jetons : positive pour un gain, négative pour une perte. Le plus gros tapis en fin de session gagne." },
  { id: "dominos", name: "Dominos", cat: "societe", engine: "cumul", team: false, target: 100, high: false,
    rules: "Quand un joueur pose son dernier domino, ou que la partie est bloquée faute de coup possible, les autres comptent les points des dominos qui leur restent en main.\n\nCes points s'ajoutent à leur passif. Le score cumulé le plus bas à l'objectif gagne." },
  { id: "millebornes", name: "Mille Bornes", cat: "cartes", engine: "cumul", team: false, target: 5000, high: true,
    rules: "On avance en posant des cartes bornes, en se défendant des attaques et en jouant ses bottes. La manche s'arrête à 1000 bornes.\n\nAu décompte : les bornes parcourues comptent pour leur distance, chaque botte vaut 100 points, un coup fourré en ajoute 300, l'allonge 200, boucler les 1000 bornes sans jamais poser de carte 200 en rapporte 300, et le capot — l'adversaire n'a pas avancé d'une seule borne — 500.\n\nSaisissez le total de chaque joueur à la fin de la manche. Premier à l'objectif gagne." },
  { id: "molkky", name: "Mölkky", cat: "sport", engine: "molkky", team: false, target: 50, high: true,
    rules: "Douze quilles numérotées de 1 à 12, lancées avec le mölkky à la main, par en dessous.\n\nUne seule quille renversée rapporte son numéro. Plusieurs quilles renversées rapportent leur nombre : deux quilles font deux points, quels que soient leurs numéros. Les quilles se relèvent là où elles sont tombées, et le jeu s'étale au fil des lancers.\n\nIl faut atteindre exactement 50. Dépasser fait retomber le score à 25.\n\nTrois lancers ratés d'affilée éliminent le joueur." },
  { id: "dekal", name: "Dékal", cat: "societe", engine: "cumul", team: false, target: 100, high: false,
    rules: "Cent cartes numérotées de 1 à 10, dix de chaque. Chacun étale devant lui seize cartes face cachée, en une grille de quatre sur quatre.\n\nLa manche dure seize tours. À chaque tour, tout le monde retourne en même temps une carte de sa grille, puis la réinsère en la glissant par l'extérieur d'une ligne ou d'une colonne : toute la rangée se décale d'un cran et vient combler le trou laissé par la carte retirée.\n\nAu décompte, deux cartes de même valeur côte à côte — horizontalement ou verticalement — s'annulent et sortent de la grille. Le score de la manche est la somme de ce qui reste.\n\nCes points s'ajoutent au passif. Dès qu'un joueur atteint 100, la partie s'arrête : le plus petit total gagne." },
  { id: "phase10", name: "Phase 10", cat: "societe", engine: "phase", team: false, target: 0, high: false,
    rules: "Dix phases à réussir dans l'ordre, une par manche. Il faut avoir posé la sienne pour passer à la suivante ; qui la manque rejoue la même phase à la manche d'après.\n\nLes dix phases :\n• 1 — deux brelans\n• 2 — un brelan et une suite de 4\n• 3 — un carré et une suite de 4\n• 4 — une suite de 7\n• 5 — une suite de 8\n• 6 — une suite de 9\n• 7 — deux carrés\n• 8 — sept cartes d'une même couleur\n• 9 — cinq cartes de même valeur et une paire\n• 10 — cinq cartes de même valeur et un brelan\n\nDès qu'un joueur se débarrasse de sa dernière carte, la manche s'arrête et les autres comptent ce qui leur reste en main : 5 points par carte de 1 à 9, 10 points de 10 à 12, 15 points pour un « Passe » et 25 pour un joker.\n\nCes points ne servent qu'à départager. Le vainqueur est le premier à poser sa dixième phase — et si plusieurs y arrivent dans la même manche, celui des deux qui a le moins de points." },
  { id: "cinqrois", name: "Les Cinq Rois", cat: "societe", engine: "cumul", team: false, target: 0, high: false,
    roundLimit: 11,
    rules: "Deux jeux de 58 cartes en cinq couleurs — cœur, carreau, trèfle, pique et étoile — allant du 3 au Roi, plus six jokers.\n\nOnze manches, et une seule distribution possible à chaque fois : trois cartes à la première, quatre à la deuxième, et ainsi de suite jusqu'à treize à la onzième. On forme des séries — au moins trois cartes de même valeur, couleurs différentes — ou des suites d'au moins trois cartes qui se suivent dans la même couleur.\n\nL'atout de la manche est la valeur distribuée : les 3 à la première manche, les 4 à la deuxième, et les Rois à la onzième. Il remplace n'importe quelle carte, comme un joker.\n\nDès qu'un joueur pose toute sa main, chacun des autres joue un dernier tour puis compte ce qui lui reste : les cartes valent leur numéro, le Valet 11, la Dame 12, le Roi 13, un atout 20 et un joker 50.\n\nAu bout des onze manches, le plus petit total gagne." },
];

export const CATEGORIES = [
  ["all", "Tous"], ["cartes", "Cartes"], ["societe", "Société"],
  ["sport", "Sport"], ["des", "Dés"],
  // « Perso » n'apparaît que si l'utilisateur a créé au moins un jeu : une
  // catégorie toujours vide dans la barre de filtres ne renseigne personne.
  ["perso", "Perso"],
];

export const gameById = (id) => GAMES.find((g) => g.id === id);

// --- Corrections venues de Firestore --------------------------------------
//
// La collection `games` peut redéfinir certains champs d'un jeu, jeu par jeu.
// C'est ce qui permet de corriger une faute dans une règle sans republier
// l'application sur l'App Store.
//
// Seuls des champs de présentation sont concernés. `engine`, `team` et `high`
// restent dans le code : le moteur désigne une fonction de calcul, et changer
// le sens de victoire à distance réécrirait le vainqueur de parties déjà
// terminées.
// Clé dans le document Firestore → champ local. Les deux diffèrent : le
// document parle la langue d'iOS (`category`, `defaultTarget`), que ce fichier
// abrège depuis toujours. Sans cette table, une correction de catégorie
// s'appliquerait sur iOS et pas ici.
const OVERRIDABLE = {
  name: "name",
  rules: "rules",
  category: "cat",
  defaultTarget: "target",
};

const CACHE_KEY = "sm.catalog";

/**
 * Applique des corrections sur le catalogue en place.
 *
 * Un identifiant inconnu est ignoré : un jeu ne peut pas être ajouté à
 * distance, puisqu'il lui faudrait un moteur, et un moteur est du code.
 * Renvoie le nombre de jeux réellement modifiés.
 */
export function applyCatalogOverrides(overrides) {
  if (!overrides || typeof overrides !== "object") return 0;
  let changed = 0;
  for (const [id, fields] of Object.entries(overrides)) {
    const game = GAMES.find((g) => g.id === id);
    if (!game || !fields || typeof fields !== "object") continue;
    let touched = false;
    for (const [remoteKey, localKey] of Object.entries(OVERRIDABLE)) {
      if (!(remoteKey in fields)) continue;
      const value = fields[remoteKey];
      // Une valeur du mauvais type ferait plus de dégâts que pas de correction
      // du tout : un objectif en chaîne casserait toutes les comparaisons.
      const expected = localKey === "target" ? "number" : "string";
      if (typeof value !== expected) continue;
      if (expected === "number" && (!Number.isFinite(value) || value < 0)) continue;
      // Un champ vidé par erreur effacerait le nom d'un jeu ou ses règles :
      // mieux vaut garder la valeur embarquée.
      if (expected === "string" && value.trim() === "") continue;
      if (game[localKey] === value) continue;
      game[localKey] = value;
      touched = true;
    }
    if (touched) changed += 1;
  }
  return changed;
}

/** Relit les corrections mises en cache, pour les avoir dès le premier écran
 *  et même sans réseau. */
export function loadCachedCatalog() {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    return raw ? applyCatalogOverrides(JSON.parse(raw)) : 0;
  } catch {
    return 0;
  }
}

export function cacheCatalog(overrides) {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(overrides));
  } catch {
    /* quota ou navigation privée : on se contentera du catalogue embarqué */
  }
}

// Teintes des avatars — mêmes couleurs système qu'iOS (Palette dans Theme.swift).
export const HUES = ["#0a84ff", "#30b0c7", "#ff9500", "#5e5ce6", "#ff2d55", "#af52de"];

// Pictogrammes des jeux édités : on redessine le matériel plutôt que de
// reproduire des logos déposés. Mêmes tracés que GameGlyph.swift, boîte de 22.
const GLYPHS = {
  uno: `<g transform="translate(11,11)">
      <g transform="translate(-4,0) rotate(-16)"><rect x="-4.5" y="-6.5" width="9" height="13" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/></g>
      <g transform="translate(4,0) rotate(16)"><rect x="-4.5" y="-6.5" width="9" height="13" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/></g>
      <rect x="-4.5" y="-6.5" width="9" height="13" rx="1.8" fill="currentColor"/></g>`,
  skyjo: Array.from({ length: 12 }, (_, i) => {
    const row = Math.floor(i / 4), col = i % 4;
    return `<rect x="${1.4 + col * 5.2}" y="${2.8 + row * 6}" width="3.6" height="4.4" rx="0.8" fill="currentColor"/>`;
  }).join(""),
  papayoo: `<rect x="4.5" y="2.5" width="13" height="17" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="11" cy="8.8" r="1.2" fill="currentColor"/>
      <circle cx="8.8" cy="13.2" r="1.2" fill="currentColor"/>
      <circle cx="13.2" cy="13.2" r="1.2" fill="currentColor"/>`,
  scrabble: `<rect x="2.5" y="2.5" width="17" height="17" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <text x="10" y="10.5" font-size="9.5" font-weight="600" fill="currentColor" text-anchor="middle" dominant-baseline="central">A</text>
      <text x="15.5" y="15" font-size="5" font-weight="600" fill="currentColor" text-anchor="middle" dominant-baseline="central">1</text>`,
  dominos: `<rect x="5" y="2" width="12" height="18" rx="2" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <rect x="6.5" y="10.4" width="9" height="1.2" fill="currentColor"/>
      <circle cx="8.6" cy="8.1" r="1.2" fill="currentColor"/><circle cx="13.4" cy="8.1" r="1.2" fill="currentColor"/>
      <circle cx="8.6" cy="13.9" r="1.2" fill="currentColor"/><circle cx="13.4" cy="13.9" r="1.2" fill="currentColor"/>`,
  millebornes: `<rect x="5" y="2.5" width="12" height="17" rx="4" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <rect x="5.75" y="7.8" width="10.5" height="1.4" fill="currentColor"/>
      <text x="11" y="13.6" font-size="4.2" font-weight="600" fill="currentColor" text-anchor="middle" dominant-baseline="central">1000</text>`,
  // Les autres jeux : un tracé simple mais propre à chacun.
  // Trèfle pour la belote, pique pour la coinche — comme les SF Symbols côté iOS.
  belote: `<circle cx="11" cy="7.6" r="3.2" fill="currentColor"/>
      <circle cx="7.5" cy="12.7" r="3.2" fill="currentColor"/>
      <circle cx="14.5" cy="12.7" r="3.2" fill="currentColor"/>
      <path d="M11.9 13.2l1.2 5.2H8.9l1.2-5.2z" fill="currentColor"/>`,
  coinche: `<path d="M11 3.6l5.6 6.2c1.7 2 .4 5-2.2 5a3 3 0 0 1-2.2-1l.7 4.6H9.1l.7-4.6a3 3 0 0 1-2.2 1c-2.6 0-3.9-3-2.2-5L11 3.6z" fill="currentColor"/>`,
  tarot: `<path d="M11 3l1.9 5.4L18.5 9l-4.3 3.6 1.4 5.4L11 15l-4.6 3 1.4-5.4L3.5 9l5.6-.6z" fill="currentColor"/>`,
  rami: `<rect x="3" y="6" width="10" height="14" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <rect x="9" y="2" width="10" height="14" rx="1.8" fill="currentColor"/>`,
  manille: `<path d="M11 3.5l5.5 7.5-5.5 7.5L5.5 11z" fill="currentColor"/>`,
  poker: `<circle cx="11" cy="11" r="7.6" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="11" cy="11" r="3" fill="currentColor"/>
      <rect x="10.2" y="1.8" width="1.6" height="3" fill="currentColor"/>
      <rect x="10.2" y="17.2" width="1.6" height="3" fill="currentColor"/>
      <rect x="1.8" y="10.2" width="3" height="1.6" fill="currentColor"/>
      <rect x="17.2" y="10.2" width="3" height="1.6" fill="currentColor"/>`,
  flechettes: `<circle cx="11" cy="11" r="8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="11" cy="11" r="4.4" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="11" cy="11" r="1.6" fill="currentColor"/>`,
  petanque: `<circle cx="7.6" cy="13" r="4.4" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="15.4" cy="14.6" r="2.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="14.4" cy="6.4" r="1.5" fill="currentColor"/>`,
  billard: `<circle cx="11" cy="11" r="7.6" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="11" cy="11" r="3.4" fill="currentColor"/>`,
  molkky: `<rect x="8" y="5" width="6" height="13" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <rect x="8" y="9" width="6" height="1.3" fill="currentColor"/>`,
  yams: `<rect x="3" y="3" width="16" height="16" rx="3.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="7.4" cy="7.4" r="1.3" fill="currentColor"/><circle cx="14.6" cy="7.4" r="1.3" fill="currentColor"/>
      <circle cx="11" cy="11" r="1.3" fill="currentColor"/>
      <circle cx="7.4" cy="14.6" r="1.3" fill="currentColor"/><circle cx="14.6" cy="14.6" r="1.3" fill="currentColor"/>`,
  421: `<rect x="3" y="3" width="16" height="16" rx="3.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="7.4" cy="7.4" r="1.3" fill="currentColor"/><circle cx="14.6" cy="14.6" r="1.3" fill="currentColor"/>
      <circle cx="11" cy="11" r="1.3" fill="currentColor"/>`,
  backgammon: `<rect x="3" y="3" width="16" height="16" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <path d="M6 4.5l2.4 6L10.8 4.5z" fill="currentColor"/>
      <path d="M11.2 17.5l2.4-6 2.4 6z" fill="currentColor"/>`,
  bowling: `<path d="M11 3.4c2.4 0 3.6 2.6 3.4 6-.2 2.6-.6 4.4-.6 6.4 0 1.8-1.2 2.8-2.8 2.8s-2.8-1-2.8-2.8c0-2-.4-3.8-.6-6.4-.2-3.4 1-6 3.4-6z"
      fill="none" stroke="currentColor" stroke-width="1.5"/><circle cx="11" cy="6.6" r="1.1" fill="currentColor"/>`,
  // Dékal — la carte qu'on glisse par le côté pour décaler une rangée.
  // La grille seule ressemblait trop à celle de Skyjo.
  dekal: `<rect x="0.7" y="8.8" width="4.4" height="4.4" rx="0.9" fill="none" stroke="currentColor" stroke-width="1.4"/>
      <rect x="6.7" y="3.4" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="11.7" y="3.4" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="16.7" y="3.4" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="6.7" y="8.8" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="11.7" y="8.8" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="16.7" y="8.8" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="6.7" y="14.2" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="11.7" y="14.2" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>
      <rect x="16.7" y="14.2" width="4.4" height="4.4" rx="0.9" fill="currentColor"/>`,
  // Phase 10 — la liste des phases à franchir, sur une carte.
  phase10: `<rect x="4.5" y="2.5" width="13" height="17" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <rect x="7" y="6.75" width="8" height="1.4" rx="0.7" fill="currentColor"/>
      <rect x="7" y="10.05" width="8" height="1.4" rx="0.7" fill="currentColor"/>
      <rect x="7" y="13.35" width="5" height="1.4" rx="0.7" fill="currentColor"/>`,
  // Les Cinq Rois — une couronne à cinq pointes.
  cinqrois: `<path d="M4 17V8l3.5 3.5L11 5.5l3.5 6L18 8v9z" fill="currentColor"/>`,
};

// Pictogrammes au choix pour un jeu personnalisé. Les clés — star, heart,
// dice… — sont celles que stocke le document partagé avec l'app iOS, qui les
// traduit de son côté en SF Symbols.
export const SYMBOL_GLYPHS = {
  star: `<path d="M11 2.6l2.6 5.6 6 .7-4.5 4.2 1.2 6L11 16.2 5.7 19.1l1.2-6L2.4 8.9l6-.7z" fill="currentColor"/>`,
  heart: `<path d="M11 18.6l-1.2-1.1C5.3 13.4 2.6 11 2.6 8A4.4 4.4 0 0 1 7 3.6c1.5 0 3 .8 4 2 1-1.2 2.5-2 4-2A4.4 4.4 0 0 1 19.4 8c0 3-2.7 5.4-7.2 9.5z" fill="currentColor"/>`,
  dice: `<rect x="3" y="3" width="16" height="16" rx="3.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <circle cx="7.4" cy="7.4" r="1.3" fill="currentColor"/><circle cx="14.6" cy="7.4" r="1.3" fill="currentColor"/>
      <circle cx="7.4" cy="14.6" r="1.3" fill="currentColor"/><circle cx="14.6" cy="14.6" r="1.3" fill="currentColor"/>
      <circle cx="11" cy="11" r="1.3" fill="currentColor"/>`,
  cards: `<rect x="2.6" y="5.4" width="9.5" height="13.4" rx="1.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
      <rect x="9.9" y="3.2" width="9.5" height="13.4" rx="1.8" fill="currentColor"/>`,
  flag: `<path d="M5.4 2.6v17.2" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
      <path d="M6.8 4h10.6l-2.4 3.9 2.4 3.9H6.8z" fill="currentColor"/>`,
  trophy: `<path d="M7 3h8v4.4a4 4 0 0 1-8 0z" fill="currentColor"/>
      <path d="M7 4.4H4.4v1.4A3 3 0 0 0 7 8.7M15 4.4h2.6v1.4A3 3 0 0 1 15 8.7" fill="none" stroke="currentColor" stroke-width="1.4"/>
      <path d="M11 11.4v4M7.8 19h6.4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>`,
};

/**
 * Pictogramme d'un jeu.
 *
 * Un jeu personnalisé n'a pas de tracé à lui : il désigne un des symboles
 * ci-dessus. Le paramètre `symbol` est donc lu en second — d'abord le jeu
 * édité, ensuite le symbole choisi, et un cadre vide si on n'a ni l'un ni
 * l'autre.
 */
export function glyph(gameId, size = 24, symbol = null) {
  const d = GLYPHS[gameId] ?? (symbol ? SYMBOL_GLYPHS[symbol] : null);
  if (!d) return `<svg viewBox="0 0 22 22" width="${size}" height="${size}" aria-hidden="true"></svg>`;
  return `<svg viewBox="0 0 22 22" width="${size}" height="${size}" aria-hidden="true" focusable="false">${d}</svg>`;
}
