import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store
    @State private var selected: UUID?
    @State private var gameFilter: String = "all"
    @State private var mateFilter: UUID?

    // MARK: Données calculées

    private struct GameStat: Identifiable {
        let id = UUID(); let name: String; let played: Int; let won: Int
    }
    private struct PeerStat: Identifiable {
        let id = UUID(); let name: String; let colorIndex: Int; let total: Int; let wins: Int
    }
    private struct PlayerStats {
        var played = 0, won = 0
        var perGame: [GameStat] = []
        var teammates: [PeerStat] = []
        var opponents: [PeerStat] = []
        var belotePlayed = false
        var prises = 0, reussies = 0, belotePoints = 0
        var lost: Int { max(0, played - won) }
        var rate: Int { played == 0 ? 0 : Int(Double(won) / Double(played) * 100) }
        var priseRate: Int { prises == 0 ? 0 : Int(Double(reussies) / Double(prises) * 100) }
    }

    private var currentPlayer: Player? {
        if let id = selected { return store.players.first { $0.id == id } }
        return store.players.first
    }

    /// Les jeux et les coéquipiers proposés dans les filtres.
    ///
    /// Ils se lisent sur toutes les parties du joueur, sans tenir compte des
    /// filtres en cours : autrement, choisir un jeu viderait la liste des
    /// coéquipiers et on ne pourrait plus revenir en arrière.
    private func choices(for p: Player) -> (games: [(String, String)], mates: [Player]) {
        var games: [String: String] = [:]
        var mates: Set<UUID> = []
        for s in store.sessions where s.isFinished {
            guard let ti = s.entrants.firstIndex(where: { $0.playerIds.contains(p.id) }) else { continue }
            games[s.gameId] = s.gameName
            for id in s.entrants[ti].playerIds where id != p.id { mates.insert(id) }
        }
        return (games.map { ($0.key, $0.value) }.sorted { $0.1 < $1.1 },
                store.players.filter { mates.contains($0.id) })
    }

    private func computeStats(for p: Player) -> PlayerStats {
        var st = PlayerStats()
        var perGame: [String: (name: String, played: Int, won: Int)] = [:]
        var tm: [UUID: (Int, Int)] = [:]
        var op: [UUID: (Int, Int)] = [:]

        for s in store.sessions where s.isFinished {
            guard let ti = s.entrants.firstIndex(where: { $0.playerIds.contains(p.id) }) else { continue }
            if gameFilter != "all", s.gameId != gameFilter { continue }
            if let mate = mateFilter, !s.entrants[ti].playerIds.contains(mate) { continue }
            let won = (s.winnerIndex == ti)
            st.played += 1; if won { st.won += 1 }

            var g = perGame[s.gameId] ?? (s.gameName, 0, 0)
            g.played += 1; if won { g.won += 1 }; perGame[s.gameId] = g

            for pid in s.entrants[ti].playerIds where pid != p.id {
                var t = tm[pid] ?? (0, 0); t.0 += 1; if won { t.1 += 1 }; tm[pid] = t
            }
            for (idx, e) in s.entrants.enumerated() where idx != ti {
                for pid in e.playerIds {
                    var o = op[pid] ?? (0, 0); o.0 += 1; if won { o.1 += 1 }; op[pid] = o
                }
            }

            if s.gameId == "belote", let rounds = s.beloteRounds {
                st.belotePlayed = true
                for r in rounds where r.takerTeam == ti {
                    st.prises += 1; if r.contractMade { st.reussies += 1 }
                }
                for round in s.rounds where round.indices.contains(ti) {
                    st.belotePoints += round[ti]
                }
            }
        }

        func player(_ id: UUID) -> Player? { store.players.first { $0.id == id } }
        st.perGame = perGame.values
            .map { GameStat(name: $0.name, played: $0.played, won: $0.won) }
            .sorted { $0.played > $1.played }
        st.teammates = tm.compactMap { id, v in
            player(id).map { PeerStat(name: $0.name, colorIndex: $0.colorIndex, total: v.0, wins: v.1) }
        }.sorted { $0.total > $1.total }
        st.opponents = op.compactMap { id, v in
            player(id).map { PeerStat(name: $0.name, colorIndex: $0.colorIndex, total: v.0, wins: v.1) }
        }.sorted { $0.total > $1.total }
        return st
    }

    // MARK: Vue

    var body: some View {
        List {
            if store.players.isEmpty {
                Text("Ajoutez des joueurs et terminez une partie pour voir les statistiques apparaître ici.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                if let p = currentPlayer {
                    let c = choices(for: p)
                    Section {
                        Picker("Joueur", selection: Binding(
                            get: { selected ?? store.players.first?.id },
                            set: { newValue in
                                selected = newValue
                                // Les jeux et coéquipiers du joueur précédent
                                // n'ont aucune raison d'exister pour celui-ci :
                                // garder la sélection afficherait « aucune
                                // partie » sans dire pourquoi.
                                gameFilter = "all"
                                mateFilter = nil
                            }
                        )) {
                            ForEach(store.players) { Text($0.name).tag(Optional($0.id)) }
                        }
                        if c.games.count > 1 {
                            Picker("Jeu", selection: $gameFilter) {
                                Text("Tous les jeux").tag("all")
                                ForEach(c.games, id: \.0) { Text($0.1).tag($0.0) }
                            }
                        }
                        if !c.mates.isEmpty {
                            Picker("Coéquipier", selection: $mateFilter) {
                                Text("Peu importe").tag(Optional<UUID>.none)
                                ForEach(c.mates) { Text($0.name).tag(Optional($0.id)) }
                            }
                        }
                    }
                }

                if let p = currentPlayer {
                    let s = computeStats(for: p)
                    recordSection(p, s)
                    if s.perGame.count > 1 { distributionSection(s) }
                    if s.perGame.count > 1 { perGameSection(s) }
                    if !s.teammates.isEmpty { teammatesSection(s) }
                    if !s.opponents.isEmpty { opponentsSection(s) }
                    if s.belotePlayed { beloteSection(s) }
                    if s.played == 0 {
                        Text("Ce joueur n'a pas encore de partie terminée.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Statistiques")
        .nightBackground()
        .onAppear {
            if selected == nil {
                let name = store.currentUser?.name
                selected = store.players.first(where: { $0.name == name })?.id ?? store.players.first?.id
            }
        }
    }

    private func recordSection(_ p: Player, _ s: PlayerStats) -> some View {
        Section("Bilan") {
            VStack(spacing: 12) {
                HStack {
                    statBlock("\(s.played)", "Jouées")
                    statBlock("\(s.won)", "Gagnées")
                    statBlock("\(s.lost)", "Perdues")
                    statBlock("\(s.rate)%", "Victoires")
                }
                // Une jauge, pas un camembert à deux parts : « gagnées » et
                // « perdues » se lisent mieux écrits que découpés.
                VizMeter(pct: s.rate)
            }
            .padding(.vertical, 4)
        }
    }

    /// La répartition des parties — la seule vraie part-de-tout de l'écran.
    ///
    /// Elle ne dit quelque chose que sur plusieurs jeux : filtrée sur un seul,
    /// elle n'aurait qu'une part.
    private func distributionSection(_ s: PlayerStats) -> some View {
        let slices = foldTail(s.perGame.map {
            VizSlice(id: $0.name, label: $0.name, value: $0.played)
        })
        return Section("Répartition des parties") {
            VStack(spacing: 16) {
                DonutChart(slices: slices,
                           centerValue: "\(s.played)",
                           centerLabel: s.played > 1 ? String(localized: "parties") : String(localized: "partie"))
                DonutLegend(slices: slices)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    /// Le plus grand nombre de parties de l'écran, tous blocs confondus : une
    /// longueur doit vouloir dire la même chose partout.
    private func maxPlayed(_ s: PlayerStats) -> Int {
        Swift.max(1,
                  (s.perGame.map(\.played) + s.teammates.map(\.total) + s.opponents.map(\.total))
                      .max() ?? 1)
    }

    private func perGameSection(_ s: PlayerStats) -> some View {
        Section("Victoires par jeu") {
            ForEach(s.perGame) { g in
                VizBar(label: g.name, won: g.won, played: g.played, maxPlayed: maxPlayed(s))
                    .padding(.vertical, 2)
            }
            VizBarsKey()
        }
    }

    private func teammatesSection(_ s: PlayerStats) -> some View {
        Section("Avec qui") {
            ForEach(s.teammates) { t in
                VizBar(label: t.name, won: t.wins, played: t.total,
                       maxPlayed: maxPlayed(s), avatarColorIndex: t.colorIndex)
                    .padding(.vertical, 2)
            }
            VizBarsKey()
        }
    }

    private func opponentsSection(_ s: PlayerStats) -> some View {
        Section("Contre qui") {
            ForEach(s.opponents) { o in
                VizBar(label: o.name, won: o.wins, played: o.total,
                       maxPlayed: maxPlayed(s), avatarColorIndex: o.colorIndex)
                    .padding(.vertical, 2)
            }
            VizBarsKey()
        }
    }

    private func beloteSection(_ s: PlayerStats) -> some View {
        Section("Belote — mes prises") {
            HStack {
                statBlock("\(s.prises)", "Prises")
                statBlock("\(s.reussies)", "Réussies")
                statBlock("\(s.priseRate)%", "Réussite")
            }
            HStack {
                Text("Points marqués")
                Spacer()
                Text("\(s.belotePoints)").foregroundStyle(.secondary)
            }
        }
    }

    private func statBlock(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.jmScore(17))
            Text(LocalizedStringKey(label)).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
