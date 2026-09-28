import SwiftUI

struct Game421ScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var loser: Int?
    @State private var winner: Int?
    @State private var amount = 1

    private let combos: [(label: String, value: Int)] = [
        ("421", 10), ("Brelan d'As", 7), ("Brelan 6", 6), ("Brelan 5", 5),
        ("Brelan 4", 4), ("Brelan 3", 3), ("Brelan 2", 2),
        ("Tierce", 2), ("Nénette", 2), ("Autre", 1)
    ]

    private var session: ScoreSession? { store.session(id: sessionID) }

    // Phase : pot > 0 → charge ; pot == 0 → décharge.
    private func isCharge(_ s: ScoreSession) -> Bool { (s.pot ?? 1) > 0 }
    private func finished(_ s: ScoreSession) -> Bool {
        guard let j = s.jetons, (s.pot ?? 1) == 0 else { return false }
        return j.contains(0)
    }
    private func winnerIndex(_ s: ScoreSession) -> Int? {
        guard let j = s.jetons else { return nil }
        return j.firstIndex(of: 0)
    }

    var body: some View {
        Group {
            if let session {
                content(session)
                    .onAppear {
                        if session.pot == nil {
                            store.init421(sessionID: sessionID, pot: session.entrants.count <= 2 ? 11 : 21)
                        }
                    }
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
                phaseHeader(session)
                scoreboard(session)
                if finished(session), let w = winnerIndex(session) {
                    WinnerBanner(name: session.entrants[w].name,
                                 detail: String(localized: "Plus de jetons !", locale: locale),
                                 shareText: String(localized: "🎲 \(session.entrants[w].name) remporte le 421, premier débarrassé de ses jetons ! Compté avec Scornade.", locale: locale))
                    endButtons()
                } else if isCharge(session) {
                    chargeCard(session)
                } else {
                    dechargeCard(session)
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
                    Button(role: .destructive) {
                        store.init421(sessionID: sessionID, pot: session.entrants.count <= 2 ? 11 : 21)
                    } label: { Label("Réinitialiser les jetons", systemImage: "arrow.counterclockwise") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onChange(of: finished(session)) { done in
            if done, !session.manuallyFinished { store.finish(sessionID: sessionID) }
        }
    }

    private func phaseHeader(_ session: ScoreSession) -> some View {
        HStack {
            Label(isCharge(session) ? "Charge" : "Décharge",
                  systemImage: isCharge(session) ? "tray.and.arrow.down" : "tray.and.arrow.up")
                .font(.subheadline.weight(.medium))
            Spacer()
            if isCharge(session) {
                Text("Pot : \(session.pot ?? 0) jetons").foregroundStyle(.secondary).font(.subheadline)
            } else {
                Text("Premier à 0 gagne").foregroundStyle(.secondary).font(.subheadline)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.cloud)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func scoreboard(_ session: ScoreSession) -> some View {
        let jetons = session.jetons ?? Array(repeating: 0, count: session.entrants.count)
        let leader = jetons.indices.min(by: { jetons[$0] < jetons[$1] })
        return VStack(spacing: 8) {
            ForEach(session.entrants.indices, id: \.self) { i in
                let pair = Palette.pair(session.entrants[i].colorIndex)
                HStack(spacing: 10) {
                    Avatar(name: session.entrants[i].name, colorIndex: session.entrants[i].colorIndex, size: 30)
                    Text(session.entrants[i].name).font(.subheadline)
                    if i == leader, !isCharge(session) {
                        Image(systemName: "crown.fill").font(.caption2).foregroundStyle(Color.crownGold)
                    }
                    Spacer()
                    Text("\(jetons.indices.contains(i) ? jetons[i] : 0)").font(.jmScore(22))
                    Text("jetons").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(pair.bg.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Charge

    private func chargeCard(_ session: ScoreSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Qui a la plus faible main ? (il prend les jetons)")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            playerChips(session, selected: loser) { loser = $0 }
            comboGrid()
            amountRow()
            Button {
                if let l = loser { store.charge421(sessionID: sessionID, loser: l, amount: amount); reset() }
            } label: {
                Label("Valider le tour", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(loser == nil)
        }
        .padding(14)
        .background(Color.cloud.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Décharge

    private func dechargeCard(_ session: ScoreSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meilleure main (donne ses jetons)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            playerChips(session, selected: winner) { winner = $0 }
            Text("Plus faible main (reçoit)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            playerChips(session, selected: loser) { loser = $0 }
            comboGrid()
            amountRow()
            Button {
                if let w = winner, let l = loser, w != l {
                    store.decharge421(sessionID: sessionID, winner: w, loser: l, amount: amount); reset()
                }
            } label: {
                Label("Valider le tour", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(winner == nil || loser == nil || winner == loser)
        }
        .padding(14)
        .background(Color.cloud.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Sous-vues partagées

    private func playerChips(_ session: ScoreSession, selected: Int?, action: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(session.entrants.indices, id: \.self) { i in
                chip(session.entrants[i].name, selected: selected == i) { action(i) }
            }
        }
    }

    private func comboGrid() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Meilleure combinaison du tour").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(combos.indices, id: \.self) { i in
                    chip("\(combos[i].label) (\(combos[i].value))", selected: amount == combos[i].value) { amount = combos[i].value }
                }
            }
        }
    }

    private func amountRow() -> some View {
        HStack {
            Text("Jetons : \(amount)").font(.subheadline.weight(.medium))
            Spacer()
            Stepper("", value: $amount, in: 1...10).labelsHidden()
        }
    }

    private func endButtons() -> some View {
        VStack(spacing: 8) {
            Button { store.resetSession(sessionID: sessionID, keepSeries: false) } label: {
                Label("Rejouer", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Button { store.popToRoot() } label: {
                Label("Changer de jeu", systemImage: "house").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(label)).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(selected ? Color.brandLight : Color.cloud)
                .foregroundStyle(selected ? Color.brandDark : Color.secondary)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.brand : Color.clear, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func reset() { loser = nil; winner = nil; amount = 1 }
}
