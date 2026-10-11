import SwiftUI

struct PayooScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var inputs: [String] = []
    @FocusState private var focusedField: Int?

    private let roundTotal = 250
    private var session: ScoreSession? { store.session(id: sessionID) }
    private var sum: Int { inputs.compactMap { Int($0) }.reduce(0, +) }

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
        let _ = ensureInputs(count: session.entrants.count)
        ScrollView {
            VStack(spacing: 14) {
                scoreboard(session)

                if session.isFinished, let w = session.winnerIndex {
                    WinnerBanner(name: session.entrants[w].name,
                                 detail: String(localized: "\(session.total(w)) pts · \(session.rounds.count) manches", locale: locale),
                                 shareText: String(localized: "🏆 \(session.entrants[w].name) remporte \(session.gameName) avec \(session.total(w)) points en \(session.rounds.count) manches ! Compté avec Scornade.", locale: locale))
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

    // MARK: Scoreboard (le plus bas est en tête)

    private func scoreboard(_ session: ScoreSession) -> some View {
        let leader = session.entrants.indices.min(by: { session.total($0) < session.total($1) })
        return VStack(spacing: 8) {
            ForEach(session.entrants.indices, id: \.self) { i in
                let pair = Palette.pair(session.entrants[i].colorIndex)
                HStack(spacing: 10) {
                    Avatar(name: session.entrants[i].name, colorIndex: session.entrants[i].colorIndex, size: 30)
                    Text(session.entrants[i].name).font(.subheadline)
                    if i == leader, session.rounds.count > 0 {
                        Image(systemName: "crown.fill").font(.caption2).foregroundStyle(Color.crownGold)
                    }
                    Spacer()
                    Text("\(session.total(i))").font(.jmScore(20, weight: .medium))
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
            Text("Points ramassés cette manche").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            ForEach(session.entrants.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Avatar(name: session.entrants[i].name, colorIndex: session.entrants[i].colorIndex, size: 28)
                    Text(session.entrants[i].name).font(.subheadline)
                    Spacer()
                    TextField("0", text: binding(for: i))
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        .frame(width: 70).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: i)
                }
            }
            let target = fillIndex(session)
            let targetName = session.entrants.indices.contains(target) ? session.entrants[target].name : ""
            HStack {
                Button { autoComplete(session) } label: {
                    Label("Compléter \(targetName) à 250", systemImage: "wand.and.stars")
                        .font(.caption).lineLimit(1)
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("\(sum) / 250")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(sum == roundTotal ? Color.success : Color.danger)
            }
            Button { validate(session) } label: {
                Label("Valider la manche", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(sum != roundTotal)
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
                    Text("M\(idx + 1)").font(.caption).foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
                    Text(roundSummary(session, round)).font(.caption).lineLimit(1)
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

    private func roundSummary(_ session: ScoreSession, _ round: [Int]) -> String {
        session.entrants.indices.map { i in
            "\(session.entrants[i].name.prefix(3)) \(round.indices.contains(i) ? round[i] : 0)"
        }.joined(separator: " · ")
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
            set: { v in if i < inputs.count { inputs[i] = v } }
        )
    }

    /// Saisies redimensionnées au nombre de joueurs : `ensureInputs` diffère sa
    /// mise à jour au prochain tour de boucle, on ne peut pas indexer `inputs`
    /// directement sans risquer un tableau encore à l'ancienne taille.
    private func currentInputs(_ session: ScoreSession) -> [String] {
        let n = session.entrants.count
        guard inputs.count == n else { return Array(repeating: "", count: n) }
        return inputs
    }

    /// Le complément à 250 va au joueur qu'on n'a pas saisi, et non au dernier de
    /// la liste : celui qui n'a rien ramassé n'est presque jamais le dernier.
    /// Si plusieurs cases sont vides, la case active tranche, sinon la dernière
    /// vide. Sans case vide, on recalcule celle qui a le curseur, à défaut la
    /// dernière.
    private func fillIndex(_ session: ScoreSession) -> Int {
        let current = currentInputs(session)
        let last = max(0, current.count - 1)
        let blanks = current.indices.filter { current[$0].trimmingCharacters(in: .whitespaces).isEmpty }
        let focused = current.indices.contains(focusedField ?? -1) ? focusedField : nil
        if !blanks.isEmpty {
            if let focused, blanks.contains(focused) { return focused }
            return blanks[blanks.count - 1]
        }
        return focused ?? last
    }

    private func autoComplete(_ session: ScoreSession) {
        let n = session.entrants.count
        guard n > 0 else { return }
        var current = currentInputs(session)
        let i = fillIndex(session)
        let others = current.indices.reduce(0) { $0 + (i == $1 ? 0 : (Int(current[$1]) ?? 0)) }
        current[i] = String(max(0, roundTotal - others))
        inputs = current
    }

    private func validate(_ session: ScoreSession) {
        let n = session.entrants.count
        let deltas = (0..<n).map { i in i < inputs.count ? (Int(inputs[i]) ?? 0) : 0 }
        store.addRound(sessionID: sessionID, deltas: deltas)
        inputs = Array(repeating: "", count: n)
        focusedField = nil
    }
}
