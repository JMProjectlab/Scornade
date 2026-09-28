import SwiftUI

struct MolkkyScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var current = 0
    @State private var entryStr = ""
    @State private var note: String?
    @State private var missStreak: [Int] = []
    @State private var eliminated: [Bool] = []

    private let quick = Array(1...12)
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
        .onAppear { ensureTracking(count: session?.entrants.count ?? 0) }
    }

    @ViewBuilder
    private func content(_ session: ScoreSession) -> some View {
        let _ = ensureTracking(count: session.entrants.count)
        ScrollView {
            VStack(spacing: 14) {
                scoreboard(session)
                if session.isFinished, let w = session.winnerIndex {
                    WinnerBanner(name: session.entrants[w].name,
                                 detail: String(localized: "50 points pile · \(session.rounds.count) lancers", locale: locale),
                                 shareText: String(localized: "🏆 \(session.entrants[w].name) remporte le Mölkky avec 50 points pile ! Compté avec Scornade.", locale: locale))
                    endButtons()
                } else {
                    entryCard(session)
                }
            }
            .padding()
        }
        .navigationTitle(session.gameName)
        .nightBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Scoreboard

    private func scoreboard(_ session: ScoreSession) -> some View {
        let leader = session.entrants.indices.max(by: { session.total($0) < session.total($1) })
        return VStack(spacing: 8) {
            ForEach(session.entrants.indices, id: \.self) { i in
                let pair = Palette.pair(session.entrants[i].colorIndex)
                Button { if !isEliminated(i) { current = i } } label: {
                    HStack(spacing: 10) {
                        Avatar(name: session.entrants[i].name, colorIndex: session.entrants[i].colorIndex, size: 30)
                        Text(session.entrants[i].name).font(.subheadline)
                        if isEliminated(i) {
                            Text("éliminé").font(.caption2.weight(.medium)).foregroundStyle(Color.danger)
                        } else if i == leader, session.rounds.count > 0 {
                            Image(systemName: "cylinder.fill").font(.caption2).foregroundStyle(Color.brand)
                        }
                        Spacer()
                        Text("\(session.total(i))").font(.jmScore(22))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(pair.bg.opacity(isEliminated(i) ? 0.15 : (current == i ? 0.6 : 0.35)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(current == i && !isEliminated(i) ? Color.brand : Color.clear, lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isEliminated(i))
            }
        }
    }

    // MARK: Saisie d'un lancer

    private func entryCard(_ session: ScoreSession) -> some View {
        let currentTotal = session.total(current)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lancer de \(session.entrants[current].name)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(currentTotal) / 50").font(.caption.weight(.medium)).foregroundStyle(Color.brand)
            }
            HStack(spacing: 6) {
                TextField("Quilles (0–12)", text: $entryStr).keyboardType(.numberPad)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).textFieldStyle(.roundedBorder)
                Button { validate(session, Int(entryStr) ?? -1) } label: {
                    Text("Valider").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(Int(entryStr).map { $0 < 0 || $0 > 12 } ?? true)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(quick, id: \.self) { q in
                    Button { validate(session, q) } label: {
                        Text("\(q)").frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Color.cloud).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Button { validate(session, 0) } label: {
                    Label("Raté (0)", systemImage: "xmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button { store.undoLastRound(sessionID: sessionID); note = nil } label: {
                    Label("Annuler", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(session.rounds.isEmpty)
            }
            if let note {
                Text(note).font(.caption.weight(.medium)).foregroundStyle(Color.danger)
            }
        }
        .padding(14)
        .background(Color.cloud.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func endButtons() -> some View {
        VStack(spacing: 8) {
            Button { store.resetSession(sessionID: sessionID, keepSeries: false); resetTracking() } label: {
                Label("Rejouer", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Button { store.popToRoot() } label: {
                Label("Changer de jeu", systemImage: "house").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Logique

    private func validate(_ session: ScoreSession, _ score: Int) {
        guard score >= 0, score <= 12 else { return }
        let currentTotal = session.total(current)
        let newTotal = currentTotal + score
        var delta: Int
        if newTotal > 50 {
            delta = 25 - currentTotal
            note = String(localized: "Raté ! Retour à 25 points.", locale: locale)
        } else {
            delta = score
            note = nil
        }
        record(session, delta)

        if score == 0 {
            missStreak[current] += 1
            if missStreak[current] >= 3 { eliminated[current] = true }
        } else {
            missStreak[current] = 0
        }

        entryStr = ""
        if newTotal != 50 { advance(session) }
    }

    private func record(_ session: ScoreSession, _ delta: Int) {
        var deltas = Array(repeating: 0, count: session.entrants.count)
        if deltas.indices.contains(current) { deltas[current] = delta }
        store.addRound(sessionID: sessionID, deltas: deltas)
    }

    private func advance(_ session: ScoreSession) {
        let n = session.entrants.count
        guard n > 0 else { return }
        var next = (current + 1) % n
        var loops = 0
        while isEliminated(next), loops < n {
            next = (next + 1) % n
            loops += 1
        }
        current = next
    }

    private func isEliminated(_ i: Int) -> Bool { eliminated.indices.contains(i) && eliminated[i] }

    private func ensureTracking(count: Int) {
        if missStreak.count != count {
            DispatchQueue.main.async {
                if missStreak.count != count {
                    missStreak = Array(repeating: 0, count: count)
                    eliminated = Array(repeating: false, count: count)
                }
            }
        }
    }

    private func resetTracking() {
        missStreak = Array(repeating: 0, count: missStreak.count)
        eliminated = Array(repeating: false, count: eliminated.count)
        current = 0
    }
}
