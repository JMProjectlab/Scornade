import SwiftUI

/// Écran de comptage de Phase 10.
///
/// Ce jeu ne se gagne pas aux points : on gagne en posant sa dixième phase, et
/// les points ne servent qu'à départager ceux qui y arrivent dans la même
/// manche. Une manche demande donc deux choses par joueur — sa phase est-elle
/// passée, et combien de points lui restaient en main — et l'écran doit
/// montrer en permanence où chacun en est de ses dix phases.
struct Phase10ScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var inputs: [String] = []
    @State private var done: [Bool] = []

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
    }

    @ViewBuilder
    private func content(_ session: ScoreSession) -> some View {
        let _ = ensureRows(count: session.entrants.count)
        ScrollView {
            VStack(spacing: 14) {
                header(session)
                scoreboard(session)

                if session.isFinished, let w = session.winnerIndex {
                    WinnerBanner(name: session.entrants[w].name,
                                 detail: String(localized: "Dix phases posées · \(session.total(w)) pts de pénalité", locale: locale),
                                 shareText: String(localized: "🏆 \(session.entrants[w].name) boucle les dix phases de \(session.gameName) avec \(session.total(w)) points de pénalité ! Compté avec Scornade.", locale: locale))
                    endButtons()
                } else {
                    entryCard(session)
                }

                if !session.rounds.isEmpty {
                    history(session)
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
    }

    // MARK: En-tête

    private func header(_ session: ScoreSession) -> some View {
        HStack {
            Label("Manche \(session.rounds.count + (session.isFinished ? 0 : 1))",
                  systemImage: "arrow.triangle.2.circlepath")
            Spacer()
            Text("Les points départagent").foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.cloud)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Tableau — la phase en cours d'abord, le passif ensuite

    private func scoreboard(_ session: ScoreSession) -> some View {
        VStack(spacing: 8) {
            ForEach(session.entrants.indices, id: \.self) { i in
                let pair = Palette.pair(session.entrants[i].colorIndex)
                let phase = session.phase(of: i)
                HStack(spacing: 10) {
                    Avatar(name: session.entrants[i].name,
                           colorIndex: session.entrants[i].colorIndex, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.entrants[i].name).font(.subheadline).lineLimit(1)
                        if phase > 10 {
                            Text("Dix phases posées")
                                .font(.caption2).foregroundStyle(Color.success)
                        } else {
                            Text("Phase \(phase) sur 10")
                                .font(.caption2).foregroundStyle(Color.inkSecondary)
                        }
                    }
                    Spacer()
                    Text("\(session.total(i))").font(.jmScore(20, weight: .medium))
                    Text("pts").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(pair.bg.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Saisie d'une manche

    private func entryCard(_ session: ScoreSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase posée, et points restés en main")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            ForEach(session.entrants.indices, id: \.self) { i in
                let phase = session.phase(of: i)
                HStack(spacing: 10) {
                    Button {
                        toggle(i)
                    } label: {
                        Image(systemName: isDone(i) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isDone(i) ? Color.success : Color.inkSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Phase \(phase) posée par \(session.entrants[i].name)"))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.entrants[i].name).font(.subheadline).lineLimit(1)
                        Text("Phase \(phase)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("0", text: binding(for: i))
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        .frame(width: 70).textFieldStyle(.roundedBorder)
                }
            }
            Text("5 points par carte de 1 à 9, 10 de 10 à 12, 15 pour un « Passe », 25 pour un joker.")
                .font(.caption2).foregroundStyle(.secondary)
            Button { validate(session) } label: {
                Label("Valider la manche", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(14)
        .background(Color.cloud.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Historique

    private func history(_ session: ScoreSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MANCHES JOUÉES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(session.rounds.enumerated().reversed()), id: \.offset) { idx, round in
                HStack(spacing: 8) {
                    Text("M\(idx + 1)").font(.caption).foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)
                    Text(roundSummary(session, round, at: idx)).font(.caption).lineLimit(1)
                    Spacer()
                    Button(role: .destructive) {
                        store.deleteRound(sessionID: sessionID, at: idx)
                    } label: { Image(systemName: "trash").font(.caption) }
                    .buttonStyle(.borderless)
                }
                Divider()
            }
        }
        .padding(.top, 8)
    }

    private func endButtons() -> some View {
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

    // MARK: Helpers

    /// « Jim ✓ 15 » : la coche dit la phase passée, le nombre le passif.
    private func roundSummary(_ session: ScoreSession, _ round: [Int], at index: Int) -> String {
        let all = session.phaseRounds ?? []
        let flags = all.indices.contains(index) ? all[index] : []
        return session.entrants.indices.map { i in
            let ok = flags.indices.contains(i) && flags[i] ? "✓" : "·"
            return "\(session.entrants[i].name.prefix(3)) \(ok) \(round.indices.contains(i) ? round[i] : 0)"
        }.joined(separator: "  ")
    }

    private func ensureRows(count: Int) {
        if inputs.count != count || done.count != count {
            DispatchQueue.main.async {
                if inputs.count != count { inputs = Array(repeating: "", count: count) }
                if done.count != count { done = Array(repeating: false, count: count) }
            }
        }
    }

    private func isDone(_ i: Int) -> Bool { done.indices.contains(i) && done[i] }

    private func toggle(_ i: Int) {
        guard done.indices.contains(i) else { return }
        done[i].toggle()
    }

    private func binding(for i: Int) -> Binding<String> {
        Binding(
            get: { i < inputs.count ? inputs[i] : "" },
            set: { v in if i < inputs.count { inputs[i] = v } }
        )
    }

    private func validate(_ session: ScoreSession) {
        let n = session.entrants.count
        let deltas = (0..<n).map { i in i < inputs.count ? (Int(inputs[i]) ?? 0) : 0 }
        let flags = (0..<n).map { isDone($0) }
        store.addPhaseRound(sessionID: sessionID, deltas: deltas, completed: flags)
        inputs = Array(repeating: "", count: n)
        done = Array(repeating: false, count: n)
    }
}
