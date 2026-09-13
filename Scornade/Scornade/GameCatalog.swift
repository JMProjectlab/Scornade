import Foundation

enum GameCatalog {
    /// Le catalogue tel qu'il est livré avec l'application. Il fait toujours
    /// foi au premier lancement, hors ligne, et si Firestore ne dit rien.
    private static let bundled: [Game] = [
        Game(id: "belote", name: "Belote", category: "cartes", symbol: "suit.club.fill",
             engine: .contractPoints, isTeamGame: true, defaultTarget: 501, higherWins: true,
             rules: "Jeu de plis à quatre, en deux équipes, avec 32 cartes et un atout choisi à chaque donne.\n\nÀ l'atout, l'ordre change : Valet 20 points, 9 14, As 11, 10 10, Roi 4, Dame 3, le 8 et le 7 rien. Dans les autres couleurs : As 11, 10 10, Roi 4, Dame 3, Valet 2, le reste rien. Les cartes totalisent 152 points, plus 10 pour le dernier pli — le dix de der — soit 162 points par donne.\n\nLe camp qui prend s'engage à faire au moins 82 points, c'est-à-dire plus de la moitié. S'il y parvient, chaque camp marque ce qu'il a ramassé. Sinon il est dedans, et les 162 points vont entièrement à la défense.\n\nÀ 81 partout, il y a litige : le preneur ne marque rien et ses 81 points sont remis en jeu, tandis que la défense encaisse les siens. Les points remis en jeu reviennent au camp qui remporte la donne suivante — deux litiges de suite en mettent donc 162 en jeu.\n\nLa belote-rebelote — Roi et Dame d'atout dans la même main — rapporte 20 points à son camp, qui les conserve même contrat manqué. Le capot, tous les plis pour un seul camp, vaut 252 points.\n\nPremier camp à l'objectif gagne."),
        Game(id: "coinche", name: "Coinche", category: "cartes", symbol: "suit.spade.fill",
             engine: .contractPoints, isTeamGame: true, defaultTarget: 1000, higherWins: true,
             rules: "La belote, mais l'atout et l'engagement se décident aux enchères. On annonce un nombre de points de 80 à 160, de dix en dix, dans une couleur — ou un capot, voire une générale.\n\nLes 162 points de la donne se comptent comme à la belote : 152 aux cartes, 10 pour le dix de der, et 20 de plus pour la belote-rebelote. Le camp qui prend doit atteindre le contrat annoncé, sans quoi il perd tout et la défense encaisse.\n\nL'adversaire qui juge le contrat intenable peut coincher : l'enjeu double. Le camp coinché peut alors surcoincher, et l'enjeu quadruple.\n\nPremier camp à l'objectif gagne."),
        Game(id: "tarot", name: "Tarot", category: "cartes", symbol: "wand.and.stars",
             engine: .contractPoints, isTeamGame: false, defaultTarget: 500, higherWins: true,
             rules: "78 cartes : 21 atouts, l'Excuse, et quatre couleurs de 14 cartes (Roi, Dame, Cavalier, Valet, puis 10 à 1).\n\nLes trois bouts sont le 1 d'atout (le Petit), le 21 et l'Excuse. Ce sont eux qui fixent l'objectif du preneur : 56 points sans bout, 51 avec un, 41 avec deux, 36 avec les trois.\n\nLe preneur joue seul contre tous les autres — à cinq, il appelle un roi et s'associe à celui qui le détient. Quatre contrats, quatre multiplicateurs : Prise ×1, Garde ×2, Garde sans ×4, Garde contre ×6. En Prise et en Garde, le chien est retourné et le preneur fait son écart ; en Garde sans il lui revient sans être vu ; en Garde contre il va à la défense.\n\nScore d'une donne : (25 + écart) × contrat, l'écart étant la différence avec l'objectif. S'y ajoutent le petit au bout (10 × contrat, pour le camp qui remporte la dernière levée avec le Petit) et la poignée (20, 30 ou 40 points, jamais multipliés). Le preneur encaisse ce total autant de fois qu'il a d'adversaires, et chacun d'eux le perd une fois : la somme d'une donne est toujours nulle.\n\nSeuils de poignée : 13, 15 ou 18 atouts à trois joueurs ; 10, 13 ou 15 à quatre ; 8, 10 ou 13 à cinq."),
        Game(id: "papayoo", name: "Papayoo", category: "societe", symbol: "die.face.5.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 1000, higherWins: false,
             rules: "60 cartes : quatre couleurs numérotées de 1 à 10, sans aucune valeur, qui servent seulement à jouer les plis, et 20 payoos numérotés de 1 à 20.\n\nChaque payoo vaut son numéro en points de pénalité. Avant la donne, un dé (ou une carte tirée au hasard) désigne une couleur : le 7 de cette couleur devient le Papayoo et vaut 40 points à lui seul. Une manche met donc toujours 250 points en jeu — 210 pour les payoos, 40 pour le Papayoo.\n\nCartes distribuées et taille de l'écart, selon le nombre de joueurs :\n• 3 joueurs — 20 cartes, écart de 5\n• 4 joueurs — 15 cartes, écart de 5\n• 5 joueurs — 12 cartes, écart de 4\n• 6 joueurs — 10 cartes, écart de 3\n• 7 joueurs — 8 cartes, écart de 3\n• 8 joueurs — 7 cartes, écart de 3\n\nÀ sept et à huit joueurs, on retire d'abord les 1 des quatre couleurs — jamais un payoo.\n\nChacun choisit son écart et le passe face cachée à son voisin de gauche, avant de regarder celui qu'il reçoit de sa droite. On joue ensuite aux plis : il faut fournir la couleur demandée, sinon on se défausse de ce qu'on veut. Il n'y a pas d'atout, et c'est la plus forte carte de la couleur demandée qui remporte le pli, avec toutes les pénalités qu'il contient.\n\nLe total marqué sur une manche vaut toujours 250. Le moins de points possible gagne."),
        Game(id: "rami", name: "Rami", category: "cartes", symbol: "rectangle.on.rectangle",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 500, higherWins: false,
             rules: "On forme des combinaisons — suites d'au moins trois cartes de la même couleur, ou brelans et carrés de même valeur — jusqu'à poser toute sa main.\n\nDès qu'un joueur termine, les autres comptent ce qui leur reste : les figures valent 10, l'As 11 lorsqu'il suit le Roi et 1 lorsqu'il ouvre une suite, les autres cartes leur numéro, et le Joker 20 points à la plupart des tables.\n\nCes points s'ajoutent au passif. Le score cumulé le plus bas à l'objectif gagne."),
        Game(id: "uno", name: "Uno", category: "societe", symbol: "square.stack.3d.up.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 500, higherWins: true,
             rules: "Le premier à se défausser de toutes ses cartes remporte la manche et marque ce qui reste dans les mains adverses.\n\nValeurs : les cartes numérotées comptent leur chiffre ; Passe, Inversion et +2 valent 20 points chacune ; Joker et +4 en valent 50.\n\nNe pas annoncer « Uno » avant de poser son avant-dernière carte coûte deux cartes de pénalité si quelqu'un le remarque.\n\nOn joue jusqu'à 500 points, et c'est le score cumulé le plus haut qui gagne."),
        Game(id: "skyjo", name: "Skyjo", category: "societe", symbol: "star.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 100, higherWins: false,
             rules: "Chacun a une grille de douze cartes face cachée, dont les valeurs vont de −2 à 12. À son tour, on échange une carte avec la pioche ou la défausse, ou on en retourne une, pour faire baisser son total.\n\nUne colonne de trois cartes identiques est retirée du jeu : elle ne compte plus rien.\n\nLa manche s'arrête dès qu'un joueur a retourné toute sa grille. Tout le monde révèle alors ses cartes et additionne. Attention à qui ferme : il doit avoir le total le plus bas, strictement, faute de quoi son score de manche est doublé.\n\nLa partie s'arrête dès qu'un joueur atteint 100 points. Le plus petit total l'emporte."),
        Game(id: "scrabble", name: "Scrabble", category: "societe", symbol: "textformat.abc",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 0, higherWins: true,
             rules: "Chaque mot posé rapporte la valeur de ses lettres, modifiée par les cases couvertes : lettre compte double ou triple, mot compte double ou triple. Les multiplicateurs de mot s'appliquent après ceux de lettre, et une case ne sert qu'une fois.\n\nPoser ses sept lettres en un seul coup — un scrabble — ajoute 50 points de prime.\n\nEn fin de partie, chacun retranche la valeur des lettres qui lui restent, et celui qui a terminé ajoute la somme de celles des autres. Le total le plus élevé gagne."),
        Game(id: "flechettes", name: "Fléchettes", category: "sport", symbol: "target",
             engine: .countdown, isTeamGame: false, defaultTarget: 501, higherWins: false,
             rules: "Chaque joueur part de 501 et retranche ce qu'il marque à chaque volée de trois fléchettes. Le double compte deux fois la valeur du secteur, le triple trois fois, le vert extérieur 25 et le rouge central 50.\n\nIl faut tomber exactement à zéro. Une volée qui ferait passer en dessous, ou qui laisserait 1 point, est annulée : c'est le bust, et le score revient à ce qu'il était avant la volée.\n\nScornade compte en sortie simple : arriver à zéro suffit. En compétition on joue en double out, où la dernière fléchette doit se planter dans un double ou dans le rouge central — la saisie ne change pas, c'est à vous de ne valider que les sorties conformes."),
        Game(id: "petanque", name: "Pétanque", category: "sport", symbol: "circle.circle",
             engine: .mancheWinner, isTeamGame: true, defaultTarget: 13, higherWins: true,
             rules: "À chaque mène, l'équipe dont la boule est la plus proche du cochonnet marque un point par boule mieux placée que la meilleure de l'adversaire — donc de 1 à 6 points selon la formation.\n\nOn rejoue jusqu'à ce qu'une équipe atteigne 13 points."),
        Game(id: "billard", name: "Billard", category: "sport", symbol: "circle.grid.cross.fill",
             engine: .mancheWinner, isTeamGame: false, defaultTarget: 5, higherWins: true,
             rules: "Scornade compte les manches gagnées, quelle que soit la variante — 8 américain, 9, ou partie libre.\n\nLe premier au nombre de manches convenu remporte le match."),
        Game(id: "yams", name: "Yam's", category: "des", symbol: "dice.fill",
             engine: .gridScore, isTeamGame: false, defaultTarget: 0, higherWins: true,
             rules: "Treize catégories à remplir, une par tour. À chaque tour on lance cinq dés, avec deux relances possibles sur les dés de son choix.\n\nSection supérieure — des 1 aux 6 — on marque la somme des dés de la valeur choisie. Si cette section atteint 63 points, elle rapporte 35 points de bonus.\n\nSection inférieure : le brelan et le carré valent la somme des cinq dés, le full 25, la petite suite 30, la grande suite 40, le Yam's 50, et la Chance la somme des dés.\n\nUne catégorie ne se remplit qu'une fois. Quand rien ne convient, il faut en barrer une à zéro. Le plus gros total gagne."),
        Game(id: "421", name: "421", category: "des", symbol: "dice",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 0, higherWins: false,
             rules: "Trois dés, 21 jetons — 11 seulement à deux joueurs — et deux phases.\n\nLa charge : le pot se vide, et c'est le perdant de chaque coup qui ramasse les jetons. Mieux vaut en prendre le moins possible.\n\nLa décharge : une fois le pot vide, les jetons passent du meilleur au moins bon du coup. Le premier à n'en avoir plus aucun gagne.\n\nValeurs appliquées par l'application : le 421 vaut 10 jetons, le brelan d'as 7, les autres brelans leur numéro — de 6 à 2 — la tierce et la nénette 2, et toute autre combinaison 1. Ces barèmes varient d'une table à l'autre ; ce sont ceux-là que Scornade utilise."),
        Game(id: "manille", name: "Manille", category: "cartes", symbol: "suit.diamond.fill",
             engine: .cumulativePoints, isTeamGame: true, defaultTarget: 500, higherWins: true,
             rules: "Jeu de plis par équipes de deux, avec 32 cartes.\n\nL'ordre est particulier : le 10 est la carte maîtresse — la manille — suivi de l'As, appelé manillon. La manille vaut 5 points, l'As 4, le Roi 3, la Dame 2, le Valet 1 ; le 9, le 8 et le 7 ne valent rien. Soit 60 points par donne.\n\nCertaines tables ajoutent un point pour le dernier pli. C'est à convenir avant de commencer.\n\nPremier camp à l'objectif gagne."),
        Game(id: "backgammon", name: "Backgammon", category: "des", symbol: "checkerboard.rectangle",
             engine: .mancheWinner, isTeamGame: false, defaultTarget: 7, higherWins: true,
             rules: "Scornade tient le score du match, pas la partie elle-même.\n\nUne partie gagnée vaut 1 point. Elle en vaut 2 si l'adversaire n'a sorti aucun pion — le gammon — et 3 s'il lui en reste dans votre jan intérieur ou sur la barre — le backgammon. Le videau multiplie ce résultat par la valeur qu'il a atteinte.\n\nPremier au nombre de points convenu remporte le match."),
        Game(id: "bowling", name: "Bowling", category: "sport", symbol: "figure.bowling",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 0, higherWins: true,
             rules: "Dix frames par partie, deux boules par frame. Un spare ajoute les quilles de la boule suivante, un strike celles des deux boules suivantes — d'où un maximum à 300.\n\nSaisissez le score final de chaque joueur, celui qu'affiche la piste. Le plus haut gagne."),
        Game(id: "poker", name: "Poker", category: "cartes", symbol: "circle.grid.2x2.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 0, higherWins: true,
             rules: "Scornade suit le tapis de chaque joueur, pas les mains.\n\nÀ chaque étape, saisissez la variation de jetons : positive pour un gain, négative pour une perte. Le plus gros tapis en fin de session gagne."),
        Game(id: "dominos", name: "Dominos", category: "societe", symbol: "rectangle.split.2x1.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 100, higherWins: false,
             rules: "Quand un joueur pose son dernier domino, ou que la partie est bloquée faute de coup possible, les autres comptent les points des dominos qui leur restent en main.\n\nCes points s'ajoutent à leur passif. Le score cumulé le plus bas à l'objectif gagne."),
        Game(id: "millebornes", name: "Mille Bornes", category: "cartes", symbol: "car.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 5000, higherWins: true,
             rules: "On avance en posant des cartes bornes, en se défendant des attaques et en jouant ses bottes. La manche s'arrête à 1000 bornes.\n\nAu décompte : les bornes parcourues comptent pour leur distance, chaque botte vaut 100 points, un coup fourré en ajoute 300, l'allonge 200, boucler les 1000 bornes sans jamais poser de carte 200 en rapporte 300, et le capot — l'adversaire n'a pas avancé d'une seule borne — 500.\n\nSaisissez le total de chaque joueur à la fin de la manche. Premier à l'objectif gagne."),
        Game(id: "molkky", name: "Mölkky", category: "sport", symbol: "cylinder.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 50, higherWins: true,
             rules: "Douze quilles numérotées de 1 à 12, lancées avec le mölkky à la main, par en dessous.\n\nUne seule quille renversée rapporte son numéro. Plusieurs quilles renversées rapportent leur nombre : deux quilles font deux points, quels que soient leurs numéros. Les quilles se relèvent là où elles sont tombées, et le jeu s'étale au fil des lancers.\n\nIl faut atteindre exactement 50. Dépasser fait retomber le score à 25.\n\nTrois lancers ratés d'affilée éliminent le joueur."),
        Game(id: "dekal", name: "Dékal", category: "societe", symbol: "square.grid.4x3.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 100, higherWins: false,
             rules: "Cent cartes numérotées de 1 à 10, dix de chaque. Chacun étale devant lui seize cartes face cachée, en une grille de quatre sur quatre.\n\nLa manche dure seize tours. À chaque tour, tout le monde retourne en même temps une carte de sa grille, puis la réinsère en la glissant par l'extérieur d'une ligne ou d'une colonne : toute la rangée se décale d'un cran et vient combler le trou laissé par la carte retirée.\n\nAu décompte, deux cartes de même valeur côte à côte — horizontalement ou verticalement — s'annulent et sortent de la grille. Le score de la manche est la somme de ce qui reste.\n\nCes points s'ajoutent au passif. Dès qu'un joueur atteint 100, la partie s'arrête : le plus petit total gagne."),
        Game(id: "phase10", name: "Phase 10", category: "societe", symbol: "list.number",
             engine: .phaseRace, isTeamGame: false, defaultTarget: 0, higherWins: false,
             rules: "Dix phases à réussir dans l'ordre, une par manche. Il faut avoir posé la sienne pour passer à la suivante ; qui la manque rejoue la même phase à la manche d'après.\n\nLes dix phases :\n• 1 — deux brelans\n• 2 — un brelan et une suite de 4\n• 3 — un carré et une suite de 4\n• 4 — une suite de 7\n• 5 — une suite de 8\n• 6 — une suite de 9\n• 7 — deux carrés\n• 8 — sept cartes d'une même couleur\n• 9 — cinq cartes de même valeur et une paire\n• 10 — cinq cartes de même valeur et un brelan\n\nDès qu'un joueur se débarrasse de sa dernière carte, la manche s'arrête et les autres comptent ce qui leur reste en main : 5 points par carte de 1 à 9, 10 points de 10 à 12, 15 points pour un « Passe » et 25 pour un joker.\n\nCes points ne servent qu'à départager. Le vainqueur est le premier à poser sa dixième phase — et si plusieurs y arrivent dans la même manche, celui des deux qui a le moins de points."),
        Game(id: "cinqrois", name: "Les Cinq Rois", category: "societe", symbol: "crown.fill",
             engine: .cumulativePoints, isTeamGame: false, defaultTarget: 0, higherWins: false,
             roundLimit: 11,
             rules: "Deux jeux de 58 cartes en cinq couleurs — cœur, carreau, trèfle, pique et étoile — allant du 3 au Roi, plus six jokers.\n\nOnze manches, et une seule distribution possible à chaque fois : trois cartes à la première, quatre à la deuxième, et ainsi de suite jusqu'à treize à la onzième. On forme des séries — au moins trois cartes de même valeur, couleurs différentes — ou des suites d'au moins trois cartes qui se suivent dans la même couleur.\n\nL'atout de la manche est la valeur distribuée : les 3 à la première manche, les 4 à la deuxième, et les Rois à la onzième. Il remplace n'importe quelle carte, comme un joker.\n\nDès qu'un joueur pose toute sa main, chacun des autres joue un dernier tour puis compte ce qui lui reste : les cartes valent leur numéro, le Valet 11, la Dame 12, le Roi 13, un atout 20 et un joker 50.\n\nAu bout des onze manches, le plus petit total gagne."),
    ]

    static func game(id: String) -> Game? { all.first { $0.id == id } }

    /// « Perso » figure ici, mais l'accueil ne l'affiche qu'une fois un jeu
    /// créé : une catégorie toujours vide n'apprend rien à personne.
    static let categories: [(key: String, label: String)] = [
        ("all", "Tous"), ("cartes", "Cartes"),
        ("societe", "Société"), ("sport", "Sport"),
        ("des", "Dés"), ("perso", "Perso"),
    ]

    // MARK: Jeux personnalisés

    /// Les jeux créés par l'utilisateur, tenus à jour par le `Store`.
    ///
    /// Ils viennent après le catalogue livré : celui-ci ne change pas de place
    /// sous les yeux de l'utilisateur parce qu'il a inventé un jeu.
    private(set) static var custom: [Game] = []

    static func setCustom(_ games: [Game]) { custom = games }

    // MARK: Corrections venues de Firestore

    /// Le catalogue livré, corrigé par ce que dit la collection `games` de
    /// Firestore.
    private static var corrected: [Game] = bundled

    /// Le catalogue effectif : les jeux livrés, puis ceux de l'utilisateur.
    static var all: [Game] { corrected + custom }

    private static let cacheKey = "sm.catalog"

    /// Ce qu'un document Firestore peut redéfinir sur un jeu.
    ///
    /// Uniquement de la présentation. Le moteur reste dans le code — il désigne
    /// une vue de saisie et une fonction de calcul — et le sens de victoire
    /// aussi : le changer à distance réécrirait le vainqueur de parties déjà
    /// terminées, puisque `winnerIndex` se recalcule à chaque affichage.
    struct Override: Codable {
        var name: String?
        var rules: String?
        var category: String?
        var defaultTarget: Int?
    }

    /// Applique des corrections et dit si quelque chose a bougé.
    ///
    /// Un identifiant inconnu est ignoré : ajouter un jeu à distance
    /// supposerait de lui fournir un moteur, et un moteur est du code.
    @discardableResult
    static func apply(_ overrides: [String: Override]) -> Bool {
        guard !overrides.isEmpty else { return false }
        var next = bundled
        var changed = false
        for i in next.indices {
            guard let o = overrides[next[i].id] else { continue }
            if let v = o.name, !v.isEmpty, v != next[i].name { next[i].name = v; changed = true }
            if let v = o.rules, !v.isEmpty, v != next[i].rules { next[i].rules = v; changed = true }
            if let v = o.category, !v.isEmpty, v != next[i].category { next[i].category = v; changed = true }
            if let v = o.defaultTarget, v >= 0, v != next[i].defaultTarget {
                next[i].defaultTarget = v; changed = true
            }
        }
        if changed { corrected = next }
        return changed
    }

    /// Relit les corrections mises en cache, pour les avoir dès le premier
    /// écran et même sans réseau.
    static func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: Override].self, from: data)
        else { return }
        apply(decoded)
    }

    static func cache(_ overrides: [String: Override]) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
