import SwiftUI

struct TarotScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var taker: Int?
    @State private var contract = 0
    @State private var bouts = 0
    @State private var pointsStr = "0"
    @State private var petit = 0
    @State private var poignee = 0

    private let contractNames = ["Prise", "Garde", "Garde sans", "Garde contre"]
    private let targets = [56, 51, 41, 36]

    private var session: ScoreSession? { store.session(id: sessionID) }
    private var points: Int { Int(pointsStr) ?? 0 }
    private var target: Int { targets[min(max(bouts, 0), 3)] }

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
                                 detail: String(localized: "\(session.total(w)) pts · \(session.rounds.count) donnes", locale: locale),
                                 shareText: String(localized: "🃏 \(session.entrants[w].name) remporte le Tarot avec \(session.total(w)) points en \(session.rounds.count) donnes ! Compté avec Scornade.", locale: locale))
                    endButtons()
                } else {
                    donneCard(session)
                }

                if let rounds = session.tarotRounds, !rounds.isEmpty {
                    history(session, rounds: rounds)
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

    // MARK: Scoreboard

    private func scoreboard(_ session: ScoreSession) -> some View {
        VStack(spacing: 8) {
            ForEach(session.entrants.indices, id: \.self) { i in
                let pair = Palette.pair(session.entrants[i].colorIndex)
                HStack(spacing: 10) {
                    Avatar(name: session.entrants[i].name, colorIndex: session.entrants[i].colorIndex, size: 30)
                    Text(session.entrants[i].name).font(.subheadline)
                    Spacer()
                    Text("\(session.total(i))").font(.jmScore(20, weight: .medium))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(pair.bg.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Donne entry

    private var canValidate: Bool { taker != nil }

    private func donneCard(_ session: ScoreSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            takerSection(session)
            contractSection()
            pointsSection()
            bonusSection()
            if taker != nil {
                resultPreview(session)
            }
            Button(action: { validate(session) }) {
                Label("Valider la donne", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!canValidate)
        }
        .padding(14)
        .background(Color.cloud.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func takerSection(_ session: ScoreSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Qui prend ?").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(session.entrants.indices, id: \.self) { i in
                    Button { taker = i } label: {
                        Text(session.entrants[i].name).font(.subheadline.weight(.medium)).lineLimit(1)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(taker == i ? Color.brandLight : Color.cloud)
                            .foregroundStyle(taker == i ? Color.brandDark : Color.secondary)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(taker == i ? Color.brand : Color.clear, lineWidth: 2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func contractSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Contrat").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(contractNames.indices, id: \.self) { i in
                    chip(contractNames[i], selected: contract == i) { contract = i }
                }
            }
            Text("Bouts").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { b in
                    chip("\(b)", selected: bouts == b) { bouts = b }
                }
            }
        }
    }

    private func pointsSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Points du preneur").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Text("objectif \(target)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Button { setPoints(points - 1) } label: { Image(systemName: "minus") }.buttonStyle(.bordered)
                TextField("0", text: $pointsStr).keyboardType(.numberPad)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .onSubmit { setPoints(points) }
                Button { setPoints(points + 1) } label: { Image(systemName: "plus") }.buttonStyle(.bordered)
            }
        }
    }

    private func bonusSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Petit au bout").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                chip("Aucun", selected: petit == 0) { petit = 0 }
                chip("Preneur", selected: petit == 1) { petit = 1 }
                chip("Défense", selected: petit == 2) { petit = 2 }
            }
            Text("Poignée").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                chip("Non", selected: poignee == 0) { poignee = 0 }
                chip("+20", selected: poignee == 20) { poignee = 20 }
                chip("+30", selected: poignee == 30) { poignee = 30 }
                chip("+40", selected: poignee == 40) { poignee = 40 }
            }
        }
    }

    private func resultPreview(_ session: ScoreSession) -> some View {
        let round = buildRound()
        let made = round.contractMade
        let d = round.deltas(players: session.entrants.count)
        return VStack(alignment: .leading, spacing: 4) {
            Text(made ? "Contrat réussi (+\(round.ecart))" : "Contrat chuté (\(round.ecart))")
                .font(.caption.weight(.semibold))
            ForEach(session.entrants.indices, id: \.self) { i in
                HStack {
                    Text(session.entrants[i].name).font(.caption)
                    Spacer()
                    Text("\(d[i] >= 0 ? "+" : "")\(d[i])").font(.caption.weight(.medium))
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(made ? Color.successLight : Color.dangerLight)
        .foregroundStyle(made ? Color.success : Color.danger)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: History

    private func history(_ session: ScoreSession, rounds: [TarotRound]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DONNES JOUÉES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(rounds.enumerated().reversed()), id: \.offset) { idx, r in
                let takerName = session.entrants.indices.contains(r.takerIndex) ? session.entrants[r.takerIndex].name : "?"
                HStack(spacing: 8) {
                    Text("D\(idx + 1)").font(.caption).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
                    Text("\(takerName) · \(contractNames[min(max(r.contract,0),3)])").font(.caption).lineLimit(1)
                    Text(r.contractMade ? "✓" : "chute")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(r.contractMade ? Color.success : Color.danger)
                    Spacer()
                    Button { loadForEdit(idx) } label: { Image(systemName: "pencil").font(.caption) }.buttonStyle(.borderless)
                    Button(role: .destructive) { store.deleteRound(sessionID: sessionID, at: idx) } label: {
                        Image(systemName: "trash").font(.caption)
                    }.buttonStyle(.borderless)
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

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(label)).font(.subheadline).lineLimit(1)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(selected ? Color.brandLight : Color.cloud)
                .foregroundStyle(selected ? Color.brandDark : Color.secondary)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.brand : Color.clear, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func setPoints(_ v: Int) { pointsStr = String(min(91, max(0, v))) }

    private func buildRound() -> TarotRound {
        TarotRound(takerIndex: taker ?? 0, contract: contract, bouts: bouts,
                   points: points, petit: petit, poignee: poignee)
    }

    private func validate(_ session: ScoreSession) {
        store.addTarotRound(sessionID: sessionID, round: buildRound())
        resetForm()
    }

    private func resetForm() {
        taker = nil; contract = 0; bouts = 0; pointsStr = "0"; petit = 0; poignee = 0
    }

    private func loadForEdit(_ index: Int) {
        guard let rounds = session?.tarotRounds, rounds.indices.contains(index) else { return }
        let r = rounds[index]
        taker = r.takerIndex; contract = r.contract; bouts = r.bouts
        pointsStr = String(r.points); petit = r.petit; poignee = r.poignee
        store.deleteRound(sessionID: sessionID, at: index)
    }
}
