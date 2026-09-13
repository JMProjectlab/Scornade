import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var filter = "all"

    private var games: [Game] {
        filter == "all" ? GameCatalog.all : GameCatalog.all.filter { $0.category == filter }
    }

    /// « Perso » n'apparaît qu'une fois un jeu créé : une catégorie toujours
    /// vide dans la barre de filtres n'apprend rien à personne.
    private var categories: [(key: String, label: String)] {
        GameCatalog.categories.filter { $0.key != "perso" || !store.customGames.isEmpty }
    }
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack(path: $store.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let active = store.activeSession {
                        Button { store.path.append(active.id) } label: {
                            ActiveSessionCard(session: active)
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.key) { cat in
                                FilterPill(label: cat.label, selected: filter == cat.key) {
                                    filter = cat.key
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(games) { game in
                            NavigationLink(value: game) { GameCard(game: game) }
                                .buttonStyle(.plain)
                        }
                        NavigationLink(value: CustomGameRoute()) { NewGameCard() }
                            .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Scornade")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { StatsView() } label: { Image(systemName: "chart.bar") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { HistoryView() } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { PlayersView() } label: { Image(systemName: "person.2") }
                }
            }
            .navigationDestination(for: Game.self) { game in
                NewGameView(game: game) { newID in store.path.append(newID) }
            }
            .navigationDestination(for: CustomGameRoute.self) { route in
                CustomGameView(route: route,
                               existing: route.editing.flatMap { store.customGame(id: $0) })
            }
            .navigationDestination(for: UUID.self) { id in
                if let s = store.session(id: id), s.gameId == "coinche" {
                    CoincheScoringView(sessionID: id)
                } else if let s = store.session(id: id),
                   let g = GameCatalog.game(id: s.gameId),
                   g.engine == .contractPoints, g.isTeamGame {
                    BeloteScoringView(sessionID: id)
                } else if let s = store.session(id: id), s.gameId == "tarot" {
                    TarotScoringView(sessionID: id)
                } else if let s = store.session(id: id), s.gameId == "papayoo" {
                    PayooScoringView(sessionID: id)
                } else if let s = store.session(id: id), s.gameId == "yams" {
                    YamsScoringView(sessionID: id)
                } else if let s = store.session(id: id), s.gameId == "flechettes" {
                    FlechettesScoringView(sessionID: id)
                } else if let s = store.session(id: id), s.gameId == "421" {
                    Game421ScoringView(sessionID: id)
                } else if let s = store.session(id: id), s.gameId == "molkky" {
                    MolkkyScoringView(sessionID: id)
                } else if let s = store.session(id: id), s.gameId == "phase10" {
                    Phase10ScoringView(sessionID: id)
                } else {
                    ScoringView(sessionID: id)
                }
            }
        }
    }
}

struct ActiveSessionCard: View {
    let session: ScoreSession
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("EN COURS").font(.caption2.weight(.semibold)).foregroundStyle(Color.brand)
                Spacer()
                Text("Manche \(session.rounds.count)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                GameGlyph(gameId: session.gameId, size: 17, tint: .brand)
                Text(session.gameName).font(.headline)
            }
            Text(session.entrants.indices.map { "\(session.entrants[$0].name) \(session.total($0))" }
                .joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandLight)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brand, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct GameCard: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameGlyph(gameId: game.id, size: 24)
            Text(game.name).font(.subheadline.weight(.medium))
            Text(game.isTeamGame ? "Équipe" : "Individuel")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// La case vide de la grille : créer son propre jeu.
struct NewGameCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.brand)
                .frame(height: 24)
            Text("Créer un jeu").font(.subheadline.weight(.medium))
            Text("Vos propres règles de comptage")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}

struct FilterPill: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(label)).font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? Color.brandLight : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? Color.brandDark : Color.secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
