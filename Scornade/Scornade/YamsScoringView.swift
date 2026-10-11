import SwiftUI

struct YamsScoringView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    let sessionID: UUID

    @State private var selected = 0

    private let categories: [(name: String, fixed: Int?)] = [
        ("As (1)", nil), ("Deux (2)", nil), ("Trois (3)", nil),
        ("Quatre (4)", nil), ("Cinq (5)", nil), ("Six (6)", nil),
        ("Brelan", nil), ("Carré", nil), ("Full", 25),
        ("Petite suite", 30), ("Grande suite", 40), ("Yam's", 50), ("Chance", nil)
    ]

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
        let done = allFilled(session) || session.manuallyFinished
        ScrollView {
            VStack(spacing: 14) {
                scoreboard(session)
                if done, let w = winner(session) {
                    WinnerBanner(name: session.entrants[w].name,
                                 detail: String(localized: "\(total(w)) points", locale: locale),
                                 shareText: String(localized: "🎲 \(session.entrants[w].name) remporte le Yam's avec \(total(w)) points ! Compté avec Scornade.", locale: locale))
                    endButtons()
                } else {
                    card(session)
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
                    if !done {
                        Button { store.finish(sessionID: sessionID) } label: {
                            Label("Terminer la partie", systemImage: "flag.checkered")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onChange(of: allFilled(session)) { _, filled in
            if filled, !session.manuallyFinished { store.finish(sessionID: sessionID) }
        }
    }

    // MARK: Scoreboard / sélecteur de joueur

    private func scoreboard(_ session: ScoreSession) -> some View {
        let leader = session.entrants.indices.max(by: { total($0) < total($1) })
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(session.entrants.indices, id: \.self) { i in
                    Button { selected = i } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text(session.entrants[i].name).font(.subheadline.weight(.medium)).lineLimit(1)
                                if i == leader, total(i) > 0 {
                                    Image(systemName: "crown.fill").font(.caption2).foregroundStyle(Color.crownGold)
                                }
                            }
                            Text("\(total(i))").font(.jmScore(20))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(selected == i ? Color.brandLight : Color.cloud)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected == i ? Color.brand : Color.clear, lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Carte du joueur sélectionné

    private func card(_ session: ScoreSession) -> some View {
        let p = min(selected, session.entrants.count - 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Grille de \(session.entrants[p].name)").font(.headline)

            Text("PARTIE SUPÉRIEURE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(0..<6, id: \.self) { c in row(p, c) }
            HStack {
                Text("Sous-total").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(upper(p)) / 63").font(.caption.weight(.medium))
                    .foregroundStyle(upper(p) >= 63 ? Color.success : .secondary)
            }
            HStack {
                Text("Bonus (+35 si ≥ 63)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("+\(bonus(p))").font(.caption.weight(.medium))
                    .foregroundStyle(bonus(p) > 0 ? Color.success : .secondary)
            }

            Divider()
            Text("PARTIE INFÉRIEURE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(6..<13, id: \.self) { c in row(p, c) }

            Divider()
            HStack {
                Text("TOTAL").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(total(p))").font(.jmScore(22)).foregroundStyle(Color.brand)
            }
        }
        .padding(14)
        .background(Color.cloud.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ p: Int, _ c: Int) -> some View {
        let v = value(p, c)
        return HStack(spacing: 8) {
            Text(categories[c].name).font(.subheadline)
            Spacer()
            if let fixed = categories[c].fixed {
                chip("\(fixed)", selected: v == fixed) { store.setYamsCell(sessionID: sessionID, player: p, category: c, value: fixed) }
                chip("0", selected: v == 0) { store.setYamsCell(sessionID: sessionID, player: p, category: c, value: 0) }
            } else {
                TextField("—", text: cellBinding(p, c))
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .frame(width: 64).textFieldStyle(.roundedBorder)
            }
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

    // MARK: Helpers de calcul

    private func value(_ p: Int, _ c: Int) -> Int {
        guard let g = session?.yamsGrid, g.indices.contains(p), g[p].indices.contains(c) else { return -1 }
        return g[p][c]
    }
    private func upper(_ p: Int) -> Int { (0..<6).reduce(0) { $0 + max(0, value(p, $1)) } }
    private func lower(_ p: Int) -> Int { (6..<13).reduce(0) { $0 + max(0, value(p, $1)) } }
    private func bonus(_ p: Int) -> Int { upper(p) >= 63 ? 35 : 0 }
    private func total(_ p: Int) -> Int { upper(p) + bonus(p) + lower(p) }
    private func filled(_ p: Int) -> Int { (0..<13).reduce(0) { $0 + (value(p, $1) >= 0 ? 1 : 0) } }

    private func allFilled(_ session: ScoreSession) -> Bool {
        !session.entrants.isEmpty && session.entrants.indices.allSatisfy { filled($0) == 13 }
    }
    private func winner(_ session: ScoreSession) -> Int? {
        session.entrants.indices.max(by: { total($0) < total($1) })
    }

    private func cellBinding(_ p: Int, _ c: Int) -> Binding<String> {
        Binding(
            get: {
                let v = value(p, c)
                return v < 0 ? "" : String(v)
            },
            set: { str in
                let t = str.trimmingCharacters(in: .whitespaces)
                if t.isEmpty {
                    store.setYamsCell(sessionID: sessionID, player: p, category: c, value: -1)
                } else if let n = Int(t) {
                    store.setYamsCell(sessionID: sessionID, player: p, category: c, value: max(0, n))
                }
            }
        )
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(label)).font(.subheadline).frame(minWidth: 40).padding(.vertical, 6).padding(.horizontal, 4)
                .background(selected ? Color.brandLight : Color.cloud)
                .foregroundStyle(selected ? Color.brandDark : Color.secondary)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.brand : Color.clear, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
