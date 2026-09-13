import Foundation

// How scores evolve during a game.
enum ScoreDirection: String, Codable {
    case accumulate   // start at 0, add points, reach a target
    case countdown    // start at target, subtract, reach 0
}

// Maps to the "scoring engines" from the design. Simplified for the MVP.
enum ScoringEngine: String, Codable {
    case cumulativePoints   // Scrabble, Uno, Skyjo, Farkle...
    case contractPoints     // Belote, Coinche, Tarot, Payoo
    case mancheWinner       // Petanque, 8 pool, Backgammon
    case countdown          // Darts 301/501
    case gridScore          // Yam's, Bowling
    case phaseRace          // Phase 10 : on marque des pénalités, mais c'est la
                            // dixième phase franchie qui gagne

    var direction: ScoreDirection {
        self == .countdown ? .countdown : .accumulate
    }
}

struct Player: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorIndex: Int
    var email: String? = nil
}

struct Game: Identifiable, Hashable {
    var id: String          // slug, e.g. "belote"
    var name: String
    var category: String    // cartes / societe / sport / des
    var symbol: String      // SF Symbol name
    var engine: ScoringEngine
    var isTeamGame: Bool
    var defaultTarget: Int
    var higherWins: Bool    // true: highest total wins; false: lowest wins
    /// Nombre de manches fixé par la règle du jeu, 0 s'il est libre.
    ///
    /// Les Cinq Rois se jouent en onze manches, ni plus ni moins : la partie
    /// s'arrête d'elle-même, sans objectif de points à atteindre.
    var roundLimit: Int = 0
    var rules: String = ""  // rappel rapide des règles, affiché depuis NewGameView
}

// A team or a solo player taking part in a session.
struct Entrant: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String        // "Jimmy" or "Jimmy + Paul"
    var colorIndex: Int
    var playerIds: [UUID]
}

struct ScoreSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var gameId: String
    var gameName: String
    var symbol: String
    var date = Date()
    var target: Int
    var higherWins: Bool
    var direction: ScoreDirection
    var entrants: [Entrant]
    var rounds: [[Int]] = []   // each round holds one delta per entrant index
    var manuallyFinished = false
    var beloteRounds: [BeloteRound]? = nil
    var firstDealerSeat: Int? = nil
    var seriesWins: [Int]? = nil
    var tarotRounds: [TarotRound]? = nil
    var coincheRounds: [CoincheRound]? = nil
    var yamsGrid: [[Int]]? = nil   // [joueur][catégorie], -1 = vide
    var pot: Int? = nil           // 421 : jetons restant dans la cave
    var jetons: [Int]? = nil      // 421 : jetons par joueur
    var roundLimit: Int? = nil    // nombre de manches imposé par la règle (Cinq Rois : 11)
    /// Mölkky : ratés consécutifs par joueur, et joueurs éliminés.
    ///
    /// Ces deux-là appartiennent à la partie, pas à l'écran : trois ratés
    /// d'affilée éliminent un joueur, et cette élimination doit survivre à un
    /// retour à l'accueil, à une relance de l'application et au passage sur un
    /// autre appareil. Mêmes noms que côté web — c'est le même document JSON.
    var molkkyMisses: [Int]? = nil
    var molkkyOut: [Bool]? = nil
    /// Phase 10 : pour chaque manche, qui a validé sa phase.
    ///
    /// C'est la trace qui compte, pas un compteur : une manche annulée doit
    /// rendre sa phase au joueur, et un compteur ne saurait pas le faire.
    var phaseRounds: [[Bool]]? = nil

    func total(_ i: Int) -> Int {
        let sum = rounds.reduce(0) { acc, round in
            acc + (round.indices.contains(i) ? round[i] : 0)
        }
        return direction == .countdown ? max(0, target - sum) : sum
    }

    /// Belote : points restés en jeu après la dernière donne, à encaisser par
    /// le camp qui remportera la suivante.
    ///
    /// Seule la dernière donne compte : une donne tranchée solde l'ardoise. Les
    /// litiges, eux, s'enchaînent — deux de suite mettent 162 points en jeu.
    var belotePending: Int {
        guard let last = beloteRounds?.last, last.isLitige else { return 0 }
        return (last.pending ?? 0) + BeloteRound.litigePoints
    }

    /// Mölkky : ce joueur est-il éliminé ?
    func isOut(_ i: Int) -> Bool { molkkyOut?.indices.contains(i) == true && molkkyOut![i] }

    /// Mölkky : enregistre un lancer — ses points et son raté.
    ///
    /// Les deux vont ensemble : trois ratés d'affilée éliminent, et un lancer
    /// réussi remet le compteur à zéro. Même règle que `molkkyThrow` côté web.
    mutating func recordMolkkyThrow(player: Int, delta: Int, missed: Bool) {
        let n = entrants.count
        var deltas = Array(repeating: 0, count: n)
        if deltas.indices.contains(player) { deltas[player] = delta }
        rounds.append(deltas)

        var misses = molkkyMisses ?? Array(repeating: 0, count: n)
        var out = molkkyOut ?? Array(repeating: false, count: n)
        if misses.count != n { misses = Array(repeating: 0, count: n) }
        if out.count != n { out = Array(repeating: false, count: n) }
        if misses.indices.contains(player) {
            misses[player] = missed ? misses[player] + 1 : 0
            if misses[player] >= 3 { out[player] = true }
        }
        molkkyMisses = misses
        molkkyOut = out
    }

    /// Phase 10 : la phase en cours d'un joueur, de 1 à 10, puis 11 une fois
    /// les dix franchies.
    func phase(of i: Int) -> Int {
        guard let flags = phaseRounds else { return 1 }
        let done = flags.reduce(0) { $0 + (($1.indices.contains(i) && $1[i]) ? 1 : 0) }
        return min(done + 1, 11)
    }

    /// Phase 10 : les joueurs qui ont posé leur dixième phase.
    var phaseFinishers: [Int] {
        guard phaseRounds != nil else { return [] }
        return entrants.indices.filter { phase(of: $0) > 10 }
    }

    var reachedEnd: Bool {
        // Phase 10 : ce sont les phases qui terminent la partie, pas les points
        // — qui ne sont que des pénalités et n'ont pas d'objectif à atteindre.
        if phaseRounds != nil { return !phaseFinishers.isEmpty }
        if let limit = roundLimit, limit > 0, rounds.count >= limit { return true }
        switch direction {
        case .countdown:
            return entrants.indices.contains { total($0) <= 0 }
        case .accumulate:
            return target > 0 && entrants.indices.contains { total($0) >= target }
        }
    }

    var isFinished: Bool { manuallyFinished || reachedEnd }

    /// Cette manche a-t-elle un enregistrement détaillé derrière elle ?
    ///
    /// Aux jeux à contrat, les points ne sont pas saisis : ils découlent de la
    /// donne. Corriger les points à la main revient donc à jeter ce détail, et
    /// l'interface doit le dire avant, pas après.
    func hasStructuredRound(at index: Int) -> Bool {
        (beloteRounds?.indices.contains(index) ?? false)
            || (tarotRounds?.indices.contains(index) ?? false)
            || (coincheRounds?.indices.contains(index) ?? false)
    }

    // Index of the winning entrant once the game has ended.
    var winnerIndex: Int? {
        guard isFinished, !entrants.isEmpty else { return nil }
        let totals = entrants.indices.map { total($0) }
        // Phase 10 : avoir fini les dix phases prime sur le total ; si deux
        // joueurs finissent dans la même manche, le plus petit score départage.
        let finishers = phaseFinishers
        if !finishers.isEmpty {
            return finishers.min { totals[$0] < totals[$1] }
        }
        switch direction {
        case .countdown:
            return totals.firstIndex(of: totals.min() ?? 0)
        case .accumulate:
            if higherWins {
                return totals.firstIndex(of: totals.max() ?? 0)
            } else {
                return totals.firstIndex(of: totals.min() ?? 0)
            }
        }
    }
}


// Détail d'une donne de belote (moteur "contrat").
struct BeloteRound: Codable, Hashable {
    var takerTeam: Int        // 0 ou 1 : l'équipe qui prend
    var suit: String          // atout : "♠" "♥" "♦" "♣"
    var cardPoints: [Int]     // points aux cartes [équipe0, équipe1], somme = 162
    var belote: [Bool]        // belote/rebelote +20 [équipe0, équipe1]
    var capotTeam: Int?       // équipe ayant fait capot, sinon nil
    /// Points remis en jeu par le ou les litiges qui précèdent cette donne, et
    /// encaissés par le camp qui la remporte.
    ///
    /// Optionnel pour rester lisible : les parties enregistrées avant la règle
    /// du litige n'ont pas cette clé, et doivent continuer à se décoder.
    var pending: Int? = nil

    /// Le partage exact des 162 points : 81 de chaque côté.
    static let litigePoints = 81

    /// Litige : le preneur fait exactement la moitié, le contrat n'est ni tenu
    /// ni chuté.
    var isLitige: Bool {
        capotTeam == nil && cardPoints.indices.contains(takerTeam)
            && cardPoints[takerTeam] == Self.litigePoints
    }

    var contractMade: Bool {
        if capotTeam != nil { return true }
        return cardPoints[takerTeam] >= 82
    }

    func deltas() -> [Int] {
        var s = [0, 0]
        let t = takerTeam, def = 1 - takerTeam
        // Points mis en jeu par le ou les litiges précédents.
        let carried = pending ?? 0
        if let c = capotTeam {
            s[c] = 252 + (belote[c] ? 20 : 0) + carried
            let o = 1 - c
            s[o] = belote[o] ? 20 : 0
            return s
        }
        if isLitige {
            // 81 partout : la défense marque ses 81 points, ceux du preneur sont
            // remis en jeu pour la donne suivante — avec ceux déjà en attente.
            s[def] = Self.litigePoints + (belote[def] ? 20 : 0)
            s[t] = belote[t] ? 20 : 0
            return s
        }
        if cardPoints[t] >= 82 {
            for i in 0..<2 { s[i] = cardPoints[i] + (belote[i] ? 20 : 0) }
            s[t] += carried
        } else {
            // Le preneur est "dedans" : les 162 points vont à la défense
            s[def] = 162 + (belote[def] ? 20 : 0) + carried
            s[t] = belote[t] ? 20 : 0
        }
        return s
    }
}


enum AuthMode: String, Codable {
    case apple, google
    /// Usage sans compte : tout reste sur l'appareil, rien n'est synchronisé.
    /// La règle 5.1.1(v) de l'App Store interdit d'exiger une inscription pour
    /// des fonctionnalités qui n'en ont pas besoin — compter des points n'en a
    /// pas besoin.
    case guest
}

struct UserAccount: Codable, Equatable {
    var id: String
    var name: String
    var email: String?
    var mode: AuthMode

    var isGuest: Bool { mode == .guest }
}


// Détail d'une donne de tarot (3 ou 4 joueurs). Total de la donne = 0.
struct TarotRound: Codable, Hashable {
    var takerIndex: Int
    var contract: Int   // 0 Prise · 1 Garde · 2 Garde sans · 3 Garde contre
    var bouts: Int      // 0..3 oudlers
    var points: Int     // points aux cartes du preneur (0..91)
    var petit: Int      // 0 aucun · 1 preneur · 2 défense (petit au bout)
    var poignee: Int    // 0 · 20 · 30 · 40

    private var multiplier: Int { [1, 2, 4, 6][min(max(contract, 0), 3)] }
    var target: Int { [56, 51, 41, 36][min(max(bouts, 0), 3)] }
    var ecart: Int { points - target }
    var contractMade: Bool { ecart >= 0 }

    private var unit: Int {
        let base = 25 + abs(ecart)
        var u = (contractMade ? 1 : -1) * base * multiplier
        let petitSign = petit == 1 ? 1 : (petit == 2 ? -1 : 0)
        u += petitSign * 10 * multiplier
        u += (contractMade ? 1 : -1) * poignee
        return u
    }

    func deltas(players n: Int) -> [Int] {
        guard n > 1, takerIndex >= 0, takerIndex < n else {
            return Array(repeating: 0, count: max(n, 0))
        }
        var d = Array(repeating: -unit, count: n)
        d[takerIndex] = unit * (n - 1)
        return d
    }
}


// Détail d'une donne de coinche (belote coinchée). Barème standard (proche FFBelote).
struct CoincheRound: Codable, Hashable {
    var takerTeam: Int        // 0 ou 1 : l'équipe qui prend
    var suit: String          // ♠ ♥ ♦ ♣ · TA (tout atout) · SA (sans atout)
    var contract: Int         // valeur annoncée : 80,90,...,160
    var capot: Bool           // capot demandé
    var coinche: Int          // 0 normal · 1 coinché (×2) · 2 surcoinché (×4)
    var cardPoints: [Int]     // points aux plis [équipe0, équipe1], somme = 162
    var belote: [Bool]        // belote/rebelote +20 [équipe0, équipe1]

    var value: Int { capot ? 250 : contract }
    var mult: Int { coinche == 1 ? 2 : (coinche == 2 ? 4 : 1) }

    var contractMade: Bool {
        if capot { return cardPoints[takerTeam] >= 162 }
        return cardPoints[takerTeam] >= value
    }

    func deltas() -> [Int] {
        var s = [0, 0]
        let t = takerTeam, d = 1 - takerTeam
        let bt = belote[t] ? 20 : 0
        let bd = belote[d] ? 20 : 0
        if contractMade {
            if capot {
                s[t] = 250 * mult + bt
                s[d] = bd
            } else {
                s[t] = (value + cardPoints[t]) * mult + bt
                s[d] = cardPoints[d] + bd
            }
        } else {
            s[t] = bt
            s[d] = (162 + value) * mult + bd
        }
        return s
    }
}
