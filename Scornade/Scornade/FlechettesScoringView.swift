import SwiftUI

struct FlechettesScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var current = 0
    @State private var entryStr = ""
    @State private var note: String?

    private let quick = [26, 41, 45, 60, 85, 100, 140, 180]
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
        ScrollView {
            VStack(spacing: 14) {
                scoreboard(session)
                if session.isFinished, let w = session.winnerIndex {
                    WinnerBanner(name: session.entrants[w].name,
                                 detail: String(localized: "501 → 0 · \(session.rounds.count) volées", locale: locale),
                                 shareText: String(localized: "🎯 \(session.entrants[w].name) remporte les fléchettes en \(session.rounds.count) volées ! Compté avec Scornade.", locale: locale))
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
        let leader = session.entrants.indices.min(by: { session.total($0) < session.total($1) })
        return VStack(spacing: 8) {
            ForEach(session.entrants.indices, id: \.self) { i in
                let pair = Palette.pair(session.entrants[i].colorIndex)
                Button { current = i } label: {
                    HStack(spacing: 10) {
                        Avatar(name: session.entrants[i].name, colorIndex: session.entrants[i].colorIndex, size: 30)
                        Text(session.entrants[i].name).font(.subheadline)
                        if i == leader, session.rounds.count > 0 {
                            Image(systemName: "target").font(.caption2).foregroundStyle(Color.brand)
                        }
                        Spacer()
                        Text("\(session.total(i))").font(.jmScore(22))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(pair.bg.opacity(current == i ? 0.6 : 0.35))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(current == i ? Color.brand : Color.clear, lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Saisie d'une volée

    private func entryCard(_ session: ScoreSession) -> some View {
        let remaining = session.total(current)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Volée de \(session.entrants[current].name)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Text("reste \(remaining)").font(.caption.weight(.medium)).foregroundStyle(Color.brand)
            }
            HStack(spacing: 6) {
                TextField("Points (0–180)", text: $entryStr).keyboardType(.numberPad)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).textFieldStyle(.roundedBorder)
                Button { validate(session, Int(entryStr) ?? -1) } label: {
                    Text("Valider").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(Int(entryStr) == nil)
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
                    Label("Manqué (0)", systemImage: "xmark").frame(maxWidth: .infinity)
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
            Button { store.resetSession(sessionID: sessionID, keepSeries: false) } label: {
                Label("Rejouer (501)", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
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
        guard score >= 0, score <= 180 else { return }
        let remaining = session.total(current)
        let newRemaining = remaining - score
        if newRemaining < 0 || newRemaining == 1 {
            // Bust : le score n'est pas décompté (impossible de finir sur 1 avec un double)
            record(session, 0)
            note = String(localized: "Bust ! La volée ne compte pas.", locale: locale)
        } else {
            record(session, score)
            note = nil
            if newRemaining > 0 { advance(session) }
        }
        entryStr = ""
    }

    private func record(_ session: ScoreSession, _ score: Int) {
        var deltas = Array(repeating: 0, count: session.entrants.count)
        if deltas.indices.contains(current) { deltas[current] = score }
        store.addRound(sessionID: sessionID, deltas: deltas)
    }

    private func advance(_ session: ScoreSession) {
        let n = session.entrants.count
        guard n > 0 else { return }
        current = (current + 1) % n
    }
}
