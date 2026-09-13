import SwiftUI

struct NewGameView: View {
    @EnvironmentObject var store: Store
    let game: Game
    let onStart: (UUID) -> Void

    // 0 = not selected, 1 = team/selected, 2 = team 2 (team games only)
    @State private var assignment: [UUID: Int] = [:]
    @State private var target: Int
    @State private var showAddField = false
    @State private var newPlayerName = ""
    @State private var showRules = false
    @FocusState private var nameFieldFocused: Bool
    @Environment(\.locale) private var locale

    init(game: Game, onStart: @escaping (UUID) -> Void) {
        self.game = game
        self.onStart = onStart
        _target = State(initialValue: game.defaultTarget)
    }

    /// Les règles passent par le catalogue de chaînes comme le reste, mais on a
    /// besoin du texte traduit — pas d'une clé — pour le découper en lignes.
    private var localizedRules: String {
        String(localized: String.LocalizationValue(game.rules), locale: locale)
    }

    private var canStart: Bool {
        if game.isTeamGame {
            let t1 = assignment.values.filter { $0 == 1 }.count
            let t2 = assignment.values.filter { $0 == 2 }.count
            return t1 > 0 && t2 > 0
        } else {
            return assignment.values.filter { $0 == 1 }.count >= 2
        }
    }

    var body: some View {
        Form {
            Section {
                ForEach(store.players) { player in
                    PlayerAssignRow(player: player,
                                    state: assignment[player.id] ?? 0,
                                    isTeamGame: game.isTeamGame) {
                        cycle(player)
                    }
                }

                if showAddField {
                    HStack(spacing: 8) {
                        TextField("Nom du joueur", text: $newPlayerName)
                            .textInputAutocapitalization(.words)
                            .focused($nameFieldFocused)
                            .onSubmit(addPlayer)
                        Button("Ajouter", action: addPlayer)
                            .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button {
                        showAddField = true
                        nameFieldFocused = true
                    } label: {
                        Label("Nouveau joueur", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.brand)
                    }
                }
            } header: {
                Text(game.isTeamGame ? "Touchez pour assigner · re-touchez pour retirer" : "Touchez pour ajouter ou retirer")
            }

            // Pas d'objectif à régler quand la règle du jeu le fixe elle-même :
            // Phase 10 se gagne aux phases, les Cinq Rois tiennent en onze
            // manches, et le Yam's comme le 421 ont leur propre fin de partie.
            if game.engine != .gridScore, game.engine != .phaseRace,
               game.roundLimit == 0, game.id != "421" {
                Section("Objectif") {
                    Stepper(value: $target, in: 0...10000, step: stepSize) {
                        HStack {
                            Text(target == 0 ? "Fin de partie libre" : "\(target) points")
                            Spacer()
                            Text(game.higherWins ? "le + haut gagne" : "le + bas gagne")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    let session = store.createSession(game: game, entrants: buildEntrants(), target: target)
                    onStart(session.id)
                } label: {
                    Text("Lancer la partie").frame(maxWidth: .infinity)
                }
                .disabled(!canStart)
            }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if CustomGame.isCustom(game.id) {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: CustomGameRoute(editing: game.id)) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Modifier ce jeu")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showRules = true } label: { Image(systemName: "questionmark.circle") }
                    .disabled(game.rules.isEmpty)
            }
        }
        .sheet(isPresented: $showRules) {
            NavigationStack {
                ScrollView {
                    // Les règles tiennent sur plusieurs paragraphes depuis
                    // qu'elles disent vraiment comment on joue. On les découpe
                    // nous-mêmes : l'interprétation Markdown de
                    // `LocalizedStringKey` ne garantit pas les sauts de ligne.
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(localizedRules.split(separator: "\n",
                                                           omittingEmptySubsequences: false).enumerated()),
                                id: \.offset) { _, line in
                            let text = String(line)
                            if !text.isEmpty {
                                Text(text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Règles · \(game.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { showRules = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var stepSize: Int {
        switch game.engine {
        case .mancheWinner: return 1
        case .countdown: return 100
        default: return target < 50 ? 5 : 50
        }
    }

    private func addPlayer() {
        let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        nameFieldFocused = false          // libère le clavier d'abord
        store.addPlayer(name: trimmed, email: nil)
        newPlayerName = ""
        showAddField = false
    }


    private func cycle(_ player: Player) {
        let current = assignment[player.id] ?? 0
        let maxState = game.isTeamGame ? 2 : 1
        assignment[player.id] = current >= maxState ? 0 : current + 1
    }

    private func buildEntrants() -> [Entrant] {
        if game.isTeamGame {
            let t1 = store.players.filter { assignment[$0.id] == 1 }
            let t2 = store.players.filter { assignment[$0.id] == 2 }
            return [
                Entrant(name: t1.map(\.name).joined(separator: " + "),
                        colorIndex: 0, playerIds: t1.map(\.id)),
                Entrant(name: t2.map(\.name).joined(separator: " + "),
                        colorIndex: 4, playerIds: t2.map(\.id)),
            ]
        } else {
            let selected = store.players.filter { assignment[$0.id] == 1 }
            return selected.map {
                Entrant(name: $0.name, colorIndex: $0.colorIndex, playerIds: [$0.id])
            }
        }
    }
}

struct PlayerAssignRow: View {
    let player: Player
    let state: Int
    let isTeamGame: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Avatar(name: player.name, colorIndex: player.colorIndex)
                Text(player.name).foregroundStyle(.primary)
                Spacer()
                badge
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var badge: some View {
        if state == 0 {
            Image(systemName: "circle").foregroundStyle(.secondary)
        } else if !isTeamGame {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brand)
        } else {
            Text(state == 1 ? "Équipe 1" : "Équipe 2")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(state == 1 ? Color.brandLight : Color.teamTwoLight)
                .foregroundStyle(state == 1 ? Color.brandDark : Color.teamTwoDark)
                .clipShape(Capsule())
        }
    }
}

struct Avatar: View {
    let name: String
    let colorIndex: Int
    var size: CGFloat = 36
    var body: some View {
        let pair = Palette.pair(colorIndex)
        Text(name.initials)
            .font(.system(size: size * 0.36, weight: .medium))
            .frame(width: size, height: size)
            .background(pair.bg).foregroundStyle(pair.fg)
            .clipShape(Circle())
    }
}
