import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class Store: ObservableObject {
    @Published var players: [Player] = []
    @Published var sessions: [ScoreSession] = []
    @Published var path = NavigationPath()
    @Published var currentUser: UserAccount?

    private let userKey = "sm.user"

    // MARK: Espaces de stockage local
    //
    // Un espace par compte, plus un pour le mode sans compte. Avant, tout
    // vivait sous deux clés communes : en changeant de compte, les joueurs et
    // les parties du compte précédent restaient en mémoire, puis partaient
    // sur le serveur du suivant. C'est ce qui recopiait « Manon » d'un compte
    // Google vers un compte Apple. Désormais, rien ne passe d'un espace à
    // l'autre sans que l'utilisateur l'ait accepté (voir `resolveGuestImport`).

    private static let guestSpace = "guest"
    private let legacyPlayersKey = "sm.players"
    private let legacySessionsKey = "sm.sessions"

    /// L'espace du compte ouvert ; nil tant que personne n'est connecté.
    private var space: String? {
        guard let u = currentUser else { return nil }
        return u.isGuest ? Self.guestSpace : u.id
    }
    private func playersKey(_ space: String) -> String { "sm.players.\(space)" }
    private func sessionsKey(_ space: String) -> String { "sm.sessions.\(space)" }
    private func declinedImportKey(_ space: String) -> String { "sm.guestImport.declined.\(space)" }

    /// Ce qui existe en mode sans compte et manque au compte qui vient de se
    /// connecter. Non nil : l'app demande s'il faut l'importer.
    @Published var pendingGuestImport: GuestImport?

    struct GuestImport: Identifiable {
        let id = UUID()
        let players: Int
        let sessions: Int
    }

    // MARK: Firestore
    //
    // Arborescence : users/{uid}/players/{id} et users/{uid}/sessions/{id}.
    // Chaque document porte le modèle sérialisé en JSON dans un champ `payload`,
    // plus un `updatedAt` pour l'ordonnancement. Firestore n'accepte pas les
    // tableaux de tableaux, or `rounds` et `yamsGrid` en sont : le JSON évite
    // d'avoir à les envelopper, et donne au futur client web exactement la même
    // forme de données qu'ici.
    //
    // Conséquence assumée : la réconciliation se fait au document entier, pas au
    // champ. Deux appareils qui modifient la même partie en même temps s'écrasent
    // (le dernier écrit gagne). C'est acceptable tant qu'une partie est tenue par
    // un seul appareil à la fois ; le partage à plusieurs demandera un vrai
    // découpage en sous-collection de manches.

    private static let payloadField = "payload"
    private static let updatedAtField = "updatedAt"

    private lazy var db = Firestore.firestore()
    private var playersListener: ListenerRegistration?
    private var sessionsListener: ListenerRegistration?
    private var catalogListener: ListenerRegistration?

    /// Change de valeur quand le catalogue est corrigé depuis Firestore.
    ///
    /// `GameCatalog.all` n'est pas observable — c'est un type statique lu un
    /// peu partout. Publier ici suffit à faire redessiner les écrans, qui
    /// observent déjà le store.
    @Published private(set) var catalogRevision = 0

    /// Dernier JSON réellement envoyé pour chaque document, pour ne pousser que
    /// ce qui a changé plutôt que la collection entière à chaque sauvegarde.
    private var pushedPlayers: [String: String] = [:]
    private var pushedSessions: [String: String] = [:]

    /// La connexion est obligatoire : sans compte Firebase authentifié, il n'y a
    /// rien à synchroniser. Le cache local sert alors de secours hors-ligne.
    private var syncEnabled: Bool {
        FirebaseSupport.isAvailable && Auth.auth().currentUser != nil && currentUser != nil
    }

    private var uid: String? { Auth.auth().currentUser?.uid }

    init() {
        load()
        // Les corrections déjà reçues s'appliquent avant le premier écran :
        // pas de libellé qui change sous les yeux une seconde plus tard.
        GameCatalog.loadCached()
        startSyncIfSignedIn()
    }

    // MARK: Players

    func addPlayer(name: String, email: String?) {
        let used = Set(players.map(\.colorIndex))
        let free = (0..<Palette.pairs.count).first { !used.contains($0) } ?? players.count
        players.append(Player(name: name, colorIndex: free, email: email))
        save()
    }

    func removePlayer(_ player: Player) {
        players.removeAll { $0.id == player.id }
        save()
    }

    // MARK: Sessions

    @discardableResult
    func createSession(game: Game, entrants: [Entrant], target: Int) -> ScoreSession {
        let session = ScoreSession(
            gameId: game.id,
            gameName: game.name,
            symbol: game.symbol,
            target: target,
            higherWins: game.higherWins,
            direction: game.engine.direction,
            entrants: entrants,
            roundLimit: game.roundLimit > 0 ? game.roundLimit : nil,
            phaseRounds: game.engine == .phaseRace ? [] : nil
        )
        sessions.insert(session, at: 0)
        save()
        return session
    }

    func session(id: UUID) -> ScoreSession? { sessions.first { $0.id == id } }

    func player(id: UUID) -> Player? { players.first { $0.id == id } }

    func addRound(sessionID: UUID, deltas: [Int]) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].rounds.append(deltas)
        save()
    }

    func addBeloteRound(sessionID: UUID, round: BeloteRound) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].beloteRounds = (sessions[i].beloteRounds ?? []) + [round]
        sessions[i].rounds.append(round.deltas())
        save()
    }

    func addTarotRound(sessionID: UUID, round: TarotRound) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].tarotRounds = (sessions[i].tarotRounds ?? []) + [round]
        sessions[i].rounds.append(round.deltas(players: sessions[i].entrants.count))
        save()
    }

    func addCoincheRound(sessionID: UUID, round: CoincheRound) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].coincheRounds = (sessions[i].coincheRounds ?? []) + [round]
        sessions[i].rounds.append(round.deltas())
        save()
    }

    /// Phase 10 : une manche, ce sont des points de pénalité **et** la liste de
    /// ceux qui ont posé leur phase. Les deux vont ensemble — annuler la manche
    /// doit rendre sa phase à chacun.
    func addPhaseRound(sessionID: UUID, deltas: [Int], completed: [Bool]) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let n = sessions[i].entrants.count
        let flags = (0..<n).map { completed.indices.contains($0) && completed[$0] }
        sessions[i].phaseRounds = (sessions[i].phaseRounds ?? []) + [flags]
        sessions[i].rounds.append((0..<n).map { deltas.indices.contains($0) ? deltas[$0] : 0 })
        save()
    }

    func init421(sessionID: UUID, pot: Int) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].pot = pot
        sessions[i].jetons = Array(repeating: 0, count: sessions[i].entrants.count)
        save()
    }

    func charge421(sessionID: UUID, loser: Int, amount: Int) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }),
              var pot = sessions[i].pot, var j = sessions[i].jetons,
              j.indices.contains(loser) else { return }
        let move = min(amount, pot)
        pot -= move
        j[loser] += move
        sessions[i].pot = pot
        sessions[i].jetons = j
        save()
    }

    func decharge421(sessionID: UUID, winner: Int, loser: Int, amount: Int) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }),
              var j = sessions[i].jetons,
              j.indices.contains(winner), j.indices.contains(loser) else { return }
        let move = min(amount, j[winner])
        j[winner] -= move
        j[loser] += move
        sessions[i].jetons = j
        save()
    }

    func setYamsCell(sessionID: UUID, player: Int, category: Int, value: Int) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let n = sessions[i].entrants.count
        var grid = sessions[i].yamsGrid ?? Array(repeating: Array(repeating: -1, count: 13), count: n)
        if grid.count != n { grid = Array(repeating: Array(repeating: -1, count: 13), count: n) }
        if grid.indices.contains(player), grid[player].indices.contains(category) {
            grid[player][category] = value
        }
        sessions[i].yamsGrid = grid
        save()
    }

    func deleteRound(sessionID: UUID, at index: Int) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }),
              sessions[i].rounds.indices.contains(index) else { return }
        sessions[i].rounds.remove(at: index)
        removeStructuredRound(&sessions[i], at: index)
        sessions[i].manuallyFinished = false
        save()
    }

    /// Corrige les points d'une manche déjà jouée.
    ///
    /// Aux jeux à contrat, `rounds` est calculé à partir d'un enregistrement
    /// détaillé (la donne, le contrat, les bouts…). Réécrire les deltas sans
    /// toucher à cet enregistrement les ferait diverger : l'historique
    /// afficherait une donne qui ne correspond plus aux points comptés. On
    /// supprime donc l'enregistrement détaillé de cette manche-là, ce qui la
    /// ramène à une manche ordinaire — les autres gardent leur détail.
    func updateRound(sessionID: UUID, at index: Int, deltas: [Int]) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }),
              sessions[i].rounds.indices.contains(index) else { return }
        let n = sessions[i].entrants.count
        sessions[i].rounds[index] = (0..<n).map { deltas.indices.contains($0) ? deltas[$0] : 0 }
        removeStructuredRound(&sessions[i], at: index, keepPhases: true)
        sessions[i].manuallyFinished = false
        save()
    }

    /// `keepPhases` sert à la correction de points : à Phase 10, la phase posée
    /// pendant la manche reste acquise même si son décompte était faux. La
    /// suppression d'une manche, elle, la reprend.
    private func removeStructuredRound(_ s: inout ScoreSession, at index: Int,
                                       keepPhases: Bool = false) {
        if var br = s.beloteRounds, br.indices.contains(index) {
            br.remove(at: index)
            s.beloteRounds = br
        }
        if var tr = s.tarotRounds, tr.indices.contains(index) {
            tr.remove(at: index)
            s.tarotRounds = tr
        }
        if var cr = s.coincheRounds, cr.indices.contains(index) {
            cr.remove(at: index)
            s.coincheRounds = cr
        }
        if !keepPhases, var pr = s.phaseRounds, pr.indices.contains(index) {
            pr.remove(at: index)
            s.phaseRounds = pr
        }
    }

    /// Rouvre une partie close à la main pour pouvoir la continuer.
    ///
    /// Une partie terminée parce qu'un joueur a atteint l'objectif reste
    /// terminée : `reachedEnd` se recalcule à partir des scores. Il faut alors
    /// corriger une manche pour repasser sous l'objectif.
    func reopen(sessionID: UUID) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].manuallyFinished = false
        save()
    }

    func setFirstDealer(sessionID: UUID, seat: Int) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].firstDealerSeat = seat
        save()
    }

    func popToRoot() { path = NavigationPath() }

    /// Rejoue une partie : remet les scores à zéro. keepSeries=true cumule les manches gagnées (la belle).
    func resetSession(sessionID: UUID, keepSeries: Bool) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        var s = sessions[i]
        if keepSeries {
            if let w = s.winnerIndex {
                var series = s.seriesWins ?? Array(repeating: 0, count: s.entrants.count)
                if series.count < s.entrants.count { series = Array(repeating: 0, count: s.entrants.count) }
                series[w] += 1
                s.seriesWins = series
            }
        } else {
            s.seriesWins = nil
        }
        s.rounds = []
        s.beloteRounds = nil
        s.tarotRounds = nil
        s.coincheRounds = nil
        s.yamsGrid = nil
        s.pot = nil
        s.jetons = nil
        // Le tableau vide dit « cette partie suit des phases » ; le mettre à nil
        // ferait retomber Phase 10 sur le décompte ordinaire.
        if s.phaseRounds != nil { s.phaseRounds = [] }
        s.manuallyFinished = false
        sessions[i] = s
        save()
    }

    func undoLastRound(sessionID: UUID) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }),
              !sessions[i].rounds.isEmpty else { return }
        let last = sessions[i].rounds.count - 1
        sessions[i].rounds.removeLast()
        // Sans cette ligne, la donne détaillée survivait à l'annulation et
        // l'historique d'une belote affichait une manche de plus que le score.
        removeStructuredRound(&sessions[i], at: last)
        sessions[i].manuallyFinished = false
        save()
    }

    func finish(sessionID: UUID) {
        guard let i = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[i].manuallyFinished = true
        save()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        save()
    }

    var activeSession: ScoreSession? { sessions.first { !$0.isFinished } }

    // MARK: Auth

    func signIn(id: String, name: String, email: String?, mode: AuthMode) {
        stopSync()
        currentUser = UserAccount(id: id, name: name, email: email, mode: mode)
        saveUser()
        // L'espace de ce compte, et lui seul : rien de l'espace précédent.
        loadSpace()
        let myEmail = email?.lowercased()
        let known = players.contains {
            $0.name == name || (myEmail != nil && $0.email?.lowercased() == myEmail)
        }
        if !known { addPlayer(name: name, email: email) }
        startSyncIfSignedIn()
        offerGuestImport()
    }

    /// Ouvre une session locale, sans compte : l'application est utilisable
    /// immédiatement et tout reste sur l'appareil. `syncEnabled` reste faux
    /// puisque `Auth.auth().currentUser` est nil, donc rien ne part sur le
    /// réseau.
    ///
    /// Les parties créées ici ne sont pas perdues si l'utilisateur se connecte
    /// plus tard : la connexion propose de les importer dans le compte.
    func continueAsGuest() {
        guard currentUser == nil else { return }
        currentUser = UserAccount(id: UUID().uuidString,
                                  name: "Joueur",
                                  email: nil,
                                  mode: .guest)
        saveUser()
        loadSpace()
    }

    /// Ferme le compte sans rien effacer : ses données restent dans son espace
    /// sur l'appareil et reviendront à la prochaine connexion. Elles quittent
    /// seulement la mémoire, pour que le compte suivant ne les voie pas.
    func signOut() {
        stopSync()
        try? Auth.auth().signOut()
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        path = NavigationPath()
        pendingGuestImport = nil
        loadSpace()
    }

    // MARK: Import des données sans compte

    private func offerGuestImport() {
        guard let space, space != Self.guestSpace,
              !UserDefaults.standard.bool(forKey: declinedImportKey(space)) else { return }
        let (guestPlayers, guestSessions) = readSpace(Self.guestSpace)
        let newPlayers = guestPlayers.filter { g in !players.contains { $0.id == g.id } }
        let newSessions = guestSessions.filter { g in !sessions.contains { $0.id == g.id } }
        guard !newPlayers.isEmpty || !newSessions.isEmpty else { return }
        pendingGuestImport = GuestImport(players: newPlayers.count, sessions: newSessions.count)
    }

    /// Accepté : les joueurs et parties sans compte rejoignent le compte, puis
    /// quittent le mode sans compte. Un joueur qui porte le même nom qu'un
    /// joueur du compte est la même personne : ses parties passent sur la fiche
    /// du compte au lieu de créer un doublon. Refusé : rien ne bouge, et la
    /// question n'est plus posée pour ce compte.
    func resolveGuestImport(accept: Bool) {
        pendingGuestImport = nil
        guard let space, space != Self.guestSpace else { return }
        guard accept else {
            UserDefaults.standard.set(true, forKey: declinedImportKey(space))
            return
        }
        let (guestPlayers, guestSessions) = readSpace(Self.guestSpace)

        var remap: [UUID: UUID] = [:]
        var merged = players
        for g in guestPlayers where !merged.contains(where: { $0.id == g.id }) {
            if let same = merged.first(where: { $0.name.localizedCaseInsensitiveCompare(g.name) == .orderedSame }) {
                remap[g.id] = same.id
            } else {
                merged.append(g)
            }
        }
        var mergedSessions = sessions
        for var g in guestSessions where !mergedSessions.contains(where: { $0.id == g.id }) {
            for j in g.entrants.indices {
                g.entrants[j].playerIds = g.entrants[j].playerIds.map { remap[$0] ?? $0 }
            }
            mergedSessions.append(g)
        }
        players = merged.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        sessions = mergedSessions.sorted { $0.date > $1.date }
        save()

        UserDefaults.standard.removeObject(forKey: playersKey(Self.guestSpace))
        UserDefaults.standard.removeObject(forKey: sessionsKey(Self.guestSpace))
    }

    // MARK: Fusion de deux fiches

    /// Deux fiches qui désignent la même personne (« Manon » saisie deux fois)
    /// n'en font plus qu'une : les parties de `duplicate` passent sur `kept`,
    /// puis `duplicate` est supprimée. Les statistiques suivent, puisqu'elles
    /// se calculent sur les identifiants des joueurs de chaque partie.
    func fusePlayer(_ duplicate: Player, into kept: Player) {
        guard duplicate.id != kept.id else { return }
        for i in sessions.indices {
            for j in sessions[i].entrants.indices
            where sessions[i].entrants[j].playerIds.contains(duplicate.id) {
                var ids: [UUID] = []
                for id in sessions[i].entrants[j].playerIds {
                    let target = id == duplicate.id ? kept.id : id
                    if !ids.contains(target) { ids.append(target) }
                }
                sessions[i].entrants[j].playerIds = ids
                if sessions[i].entrants[j].name == duplicate.name {
                    sessions[i].entrants[j].name = kept.name
                }
            }
        }
        if let k = players.firstIndex(where: { $0.id == kept.id }), players[k].email == nil {
            players[k].email = duplicate.email
        }
        players.removeAll { $0.id == duplicate.id }
        save()
    }

    /// Efface toutes les données de l'utilisateur : joueurs, parties et compte,
    /// en local ET côté serveur. Action irréversible (exigée par Apple).
    func deleteAllData() {
        let ids = (players.map(\.id.uuidString), sessions.map(\.id.uuidString))
        let wasSyncing = syncEnabled
        let spaceToErase = space
        let user = Auth.auth().currentUser

        stopSync()
        players = []
        sessions = []
        currentUser = nil
        path = NavigationPath()
        pushedPlayers = [:]
        pushedSessions = [:]
        var keys = [userKey]
        if let erased = spaceToErase { keys += [playersKey(erased), sessionsKey(erased)] }
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        guard wasSyncing, let uid = user?.uid else { return }
        let root = db.collection("users").document(uid)
        Task {
            let batch = db.batch()
            for id in ids.0 { batch.deleteDocument(root.collection("players").document(id)) }
            for id in ids.1 { batch.deleteDocument(root.collection("sessions").document(id)) }
            try? await batch.commit()
            // Le compte lui-même part avec les données : c'est ce qu'exige la
            // règle 5.1.1(v) d'Apple sur la suppression de compte depuis l'app.
            try? await user?.delete()
        }
    }

    private func saveUser() {
        if let u = currentUser, let d = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(d, forKey: userKey)
        }
    }

    // MARK: Persistance locale (chargement instantané, hors-ligne)

    func reloadFromCloud() { startSyncIfSignedIn() }

    private func save() {
        saveLocalCacheOnly()
        pushChanges()
    }

    private func saveLocalCacheOnly() {
        guard let space else { return }
        let enc = JSONEncoder()
        if let p = try? enc.encode(players) {
            UserDefaults.standard.set(p, forKey: playersKey(space))
        }
        if let s = try? enc.encode(sessions) {
            UserDefaults.standard.set(s, forKey: sessionsKey(space))
        }
    }

    private func load() {
        if let u = UserDefaults.standard.data(forKey: userKey),
           let decoded = try? JSONDecoder().decode(UserAccount.self, from: u) {
            currentUser = decoded
        }
        migrateLegacyCache()
        loadSpace()
    }

    /// Avant la séparation par compte, tout vivait sous deux clés communes. Ce
    /// contenu va à l'espace du compte ouvert (c'est ce qu'il affichait), ou au
    /// mode sans compte si personne n'est connecté. Il n'est copié nulle part
    /// ailleurs, puis les anciennes clés disparaissent.
    private func migrateLegacyCache() {
        let d = UserDefaults.standard
        guard d.data(forKey: legacyPlayersKey) != nil || d.data(forKey: legacySessionsKey) != nil else { return }
        let target = space ?? Self.guestSpace
        for (old, new) in [(legacyPlayersKey, playersKey(target)), (legacySessionsKey, sessionsKey(target))] {
            if let data = d.data(forKey: old), d.data(forKey: new) == nil {
                d.set(data, forKey: new)
            }
            d.removeObject(forKey: old)
        }
    }

    /// Remplace les données en mémoire par celles de l'espace courant (vide si
    /// personne n'est connecté).
    private func loadSpace() {
        pushedPlayers = [:]
        pushedSessions = [:]
        guard let space else {
            players = []
            sessions = []
            return
        }
        let (p, s) = readSpace(space)
        players = p
        sessions = s
    }

    private func readSpace(_ space: String) -> ([Player], [ScoreSession]) {
        let d = UserDefaults.standard
        let dec = JSONDecoder()
        let p = d.data(forKey: playersKey(space)).flatMap { try? dec.decode([Player].self, from: $0) } ?? []
        let s = d.data(forKey: sessionsKey(space)).flatMap { try? dec.decode([ScoreSession].self, from: $0) } ?? []
        return (p, s)
    }

    // MARK: Synchronisation Firestore

    private func startSyncIfSignedIn() {
        stopSync()
        guard syncEnabled, let uid else { return }
        let root = db.collection("users").document(uid)

        // Un instantané parti avant un changement de compte peut arriver après :
        // il ne s'applique que si le compte qui l'a demandé est toujours ouvert.
        playersListener = root.collection("players").addSnapshotListener { [weak self] snap, _ in
            guard let snap else { return }
            let remote = Self.decodeAll(Player.self, from: snap.documents)
            Task { @MainActor in
                guard let self, self.uid == uid else { return }
                self.mergePlayers(remote)
            }
        }
        sessionsListener = root.collection("sessions").addSnapshotListener { [weak self] snap, _ in
            guard let snap else { return }
            let remote = Self.decodeAll(ScoreSession.self, from: snap.documents)
            Task { @MainActor in
                guard let self, self.uid == uid else { return }
                self.mergeSessions(remote)
            }
        }

        // Le catalogue est commun à tous les comptes : il est en lecture seule,
        // et c'est lui qui permet de corriger une règle sans publier une
        // nouvelle version. Une collection vide est le cas normal.
        catalogListener = db.collection("games").addSnapshotListener { [weak self] snap, _ in
            guard let snap else { return }
            let overrides = Self.decodeOverrides(snap.documents)
            Task { @MainActor in
                guard let self else { return }
                GameCatalog.cache(overrides)
                if GameCatalog.apply(overrides) { self.catalogRevision += 1 }
            }
        }

        // Ce qui existe déjà en local et pas encore côté serveur part au premier envoi.
        pushChanges()
    }

    /// Les documents `games/{id}` sont des dictionnaires plats, pas le JSON
    /// encapsulé qu'on utilise pour les joueurs et les parties : ils sont
    /// rédigés à la main dans la console, autant qu'ils y soient lisibles.
    private nonisolated static func decodeOverrides(
        _ docs: [QueryDocumentSnapshot]
    ) -> [String: GameCatalog.Override] {
        var out: [String: GameCatalog.Override] = [:]
        for doc in docs {
            let d = doc.data()
            out[doc.documentID] = GameCatalog.Override(
                name: d["name"] as? String,
                rules: d["rules"] as? String,
                category: d["category"] as? String,
                defaultTarget: (d["defaultTarget"] as? NSNumber)?.intValue
            )
        }
        return out
    }

    private func stopSync() {
        playersListener?.remove(); playersListener = nil
        sessionsListener?.remove(); sessionsListener = nil
        catalogListener?.remove(); catalogListener = nil
    }

    private nonisolated static func decodeAll<T: Decodable>(_ type: T.Type,
                                                            from docs: [QueryDocumentSnapshot]) -> [T] {
        let dec = JSONDecoder()
        return docs.compactMap { doc in
            guard let json = doc[payloadField] as? String,
                  let data = json.data(using: .utf8) else { return nil }
            return try? dec.decode(T.self, from: data)
        }
    }

    /// N'envoie que les documents dont le JSON a changé, et supprime ceux qui ont
    /// disparu localement.
    private func pushChanges() {
        guard syncEnabled, let uid else { return }
        let root = db.collection("users").document(uid)
        let enc = JSONEncoder()

        let batch = db.batch()
        var writes = 0

        func stage<T: Encodable & Identifiable>(_ items: [T],
                                                into collection: String,
                                                cache: inout [String: String]) where T.ID == UUID {
            let current = Set(items.map(\.id.uuidString))
            for item in items {
                let key = item.id.uuidString
                guard let data = try? enc.encode(item),
                      let json = String(data: data, encoding: .utf8),
                      cache[key] != json else { continue }
                batch.setData([Self.payloadField: json,
                               Self.updatedAtField: FieldValue.serverTimestamp()],
                              forDocument: root.collection(collection).document(key))
                cache[key] = json
                writes += 1
            }
            // Les clés sont relevées d'abord : on ne mute pas le dictionnaire
            // pendant qu'on le parcourt.
            let removed = cache.keys.filter { !current.contains($0) }
            for gone in removed {
                batch.deleteDocument(root.collection(collection).document(gone))
                cache[gone] = nil
                writes += 1
            }
        }

        stage(players, into: "players", cache: &pushedPlayers)
        stage(sessions, into: "sessions", cache: &pushedSessions)

        guard writes > 0 else { return }
        batch.commit { _ in /* Firestore rejoue l'écriture au retour du réseau. */ }
    }

    /// Fusionne sans jamais supprimer localement : une absence côté serveur peut
    /// simplement signifier que l'entrée locale n'a pas encore été poussée.
    private func mergePlayers(_ remote: [Player]) {
        guard !remote.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        for p in remote { byID[p.id] = p }
        players = Array(byID.values).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        saveLocalCacheOnly()
    }

    private func mergeSessions(_ remote: [ScoreSession]) {
        guard !remote.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        for s in remote { byID[s.id] = s }
        sessions = Array(byID.values).sorted { $0.date > $1.date }
        saveLocalCacheOnly()
    }
}
