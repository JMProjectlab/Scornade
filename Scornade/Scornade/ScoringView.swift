import SwiftUI

struct ScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var inputs: [String] = []
    /// `sheet(item:)` réclame un identifiable ; un `Int?` n'en est pas un, et
    /// la manche 0 se confondrait de toute façon avec « aucune ».
    @State private var editingRound: EditingRound?

    private struct EditingRound: Identifiable { let id: Int }

    private var session: ScoreSession? { store.session(id: sessionID) }

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle").font(.largeTitle)
                    Text("Partie introuvable")
                }
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let s = session, inputs.count != s.entrants.count {
                inputs = Array(repeating: "", count: s.entrants.count)
            }
        }
    }

    @ViewBuilder
    private func content(_ session: ScoreSession) -> some View {
        let _ = ensureInputs(count: session.entrants.count)
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    // Les Cinq Rois tiennent en onze manches : afficher le
                    // compte à part rend visible ce qu'il reste à jouer, là où
                    // les autres jeux visent un objectif de points.
                    let number = session.rounds.count + (session.isFinished ? 0 : 1)
                    if let limit = session.roundLimit, limit > 0 {
                        Label("Manche \(number) / \(limit)",
                              systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("Manche \(number)", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Spacer()
                    if session.target > 0 {
                        Text("Objectif \(session.target)").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.cloud)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if session.isFinished, let w = session.winnerIndex {
                    WinnerBanner(name: session.entrants[w].name,
                                 detail: String(localized: "\(session.total(w)) pts · \(session.rounds.count) manches", locale: locale),
                                 shareText: String(localized: "🏆 \(session.entrants[w].name) remporte \(session.gameName) avec \(session.total(w)) points en \(session.rounds.count) manches ! Compté avec Scornade.", locale: locale))
                    VStack(spacing: 8) {
                        Button { store.resetSession(sessionID: sessionID, keepSeries: false) } label: {
                            Label("Rejouer (0 – 0)", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        Button { store.popToRoot() } label: {
                            Label("Changer de jeu", systemImage: "house").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ForEach(session.entrants.indices, id: \.self) { i in
                    EntrantRow(entrant: session.entrants[i],
                               total: session.total(i),
                               target: session.target,
                               direction: session.direction,
                               isLeader: session.winnerIndex == i && session.isFinished,
                               input: binding(for: i))
                }

                if !session.isFinished {
                    Button(action: { validate(session) }) {
                        Label("Valider la manche", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if !session.rounds.isEmpty {
                    HistorySection(session: session,
                                   onDelete: { idx in store.deleteRound(sessionID: sessionID, at: idx) },
                                   onEdit: { idx in editingRound = EditingRound(id: idx) })
                }
            }
            .padding()
        }
        .navigationTitle(session.gameName)
        .nightBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !session.rounds.isEmpty {
                        Button {
                            store.undoLastRound(sessionID: sessionID)
                        } label: {
                            Label("Annuler la dernière manche", systemImage: "arrow.uturn.backward")
                        }
                    }
                    if session.isFinished {
                        Button {
                            store.reopen(sessionID: sessionID)
                        } label: {
                            Label("Reprendre la partie", systemImage: "play.circle")
                        }
                    } else {
                        Button {
                            store.finish(sessionID: sessionID)
                        } label: {
                            Label("Terminer la partie", systemImage: "flag.checkered")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(item: $editingRound) { edit in
            let idx = edit.id
            RoundEditorSheet(entrants: session.entrants,
                             roundNumber: idx + 1,
                             deltas: session.rounds.indices.contains(idx) ? session.rounds[idx] : [],
                             losesDetail: session.hasStructuredRound(at: idx)) { deltas in
                store.updateRound(sessionID: sessionID, at: idx, deltas: deltas)
            }
        }
    }

    private func ensureInputs(count: Int) {
        if inputs.count != count {
            DispatchQueue.main.async {
                if inputs.count != count {
                    inputs = Array(repeating: "", count: count)
                }
            }
        }
    }

    private func binding(for i: Int) -> Binding<String> {
        Binding(
            get: { i < inputs.count ? inputs[i] : "" },
            set: { newValue in
                if i < inputs.count { inputs[i] = newValue }
            }
        )
    }

    private func validate(_ session: ScoreSession) {
        let deltas = inputs.map { Int($0) ?? 0 }
        store.addRound(sessionID: sessionID, deltas: deltas)
        inputs = Array(repeating: "", count: session.entrants.count)
    }
}

struct EntrantRow: View {
    let entrant: Entrant
    let total: Int
    let target: Int
    let direction: ScoreDirection
    let isLeader: Bool
    @Binding var input: String

    private var progress: Double {
        guard target > 0 else { return 0 }
        let value = direction == .countdown ? Double(target - total) : Double(total)
        return min(1, max(0, value / Double(target)))
    }

    var body: some View {
        let pair = Palette.pair(entrant.colorIndex)
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Avatar(name: entrant.name, colorIndex: entrant.colorIndex)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entrant.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    if isLeader {
                        Text("Vainqueur").font(.caption2.weight(.medium)).foregroundStyle(Color.brand)
                    }
                }
                Spacer()
                Text("\(total)").font(.jmScore(26, weight: .medium))
            }
            ProgressView(value: progress).tint(pair.fg)
            HStack(spacing: 8) {
                TextField("0", text: $input)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                Stepper("", value: Binding(
                    get: { Int(input) ?? 0 },
                    set: { input = String($0) }
                ), step: 1).labelsHidden()
            }
        }
        .padding(14)
        .background(Color.cloud)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isLeader ? Color.brand : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct WinnerBanner: View {
    let name: String
    let detail: String
    let shareText: String
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Spacer()
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(Color.success)
                }
            }
            Image(systemName: "trophy.fill").font(.title2).foregroundStyle(Color.gold)
            Text("\(name) remporte la partie !").font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color.successLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct HistorySection: View {
    let session: ScoreSession
    var onDelete: (Int) -> Void
    var onEdit: (Int) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORIQUE · touchez une manche pour la corriger")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(session.rounds.enumerated().reversed()), id: \.offset) { idx, round in
                HStack {
                    Text("M\(idx + 1)").font(.caption).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
                    Text(session.entrants.indices.map { i in
                        "\(session.entrants[i].name.initials) \(round.indices.contains(i) ? round[i] : 0)"
                    }.joined(separator: "  "))
                        .font(.caption)
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Button(role: .destructive) { onDelete(idx) } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                // La zone tactile couvre toute la ligne, sauf la corbeille qui
                // capte son propre appui.
                .contentShape(Rectangle())
                .onTapGesture { onEdit(idx) }
                Divider()
            }
        }
        .padding(.top, 8)
    }
}
