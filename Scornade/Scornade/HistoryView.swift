import SwiftUI

/// Les parties terminées, de la plus récente à la plus ancienne.
///
/// Sans cet écran, une partie disparaissait de l'interface dès qu'on quittait
/// son tableau de score : elle continuait d'alimenter les statistiques, mais
/// plus rien ne permettait d'y revenir — ni pour la relire, ni pour corriger
/// une erreur de saisie.
struct HistoryView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    @State private var pendingDeletion: ScoreSession?

    private var finished: [ScoreSession] {
        store.sessions.filter(\.isFinished).sorted { $0.date > $1.date }
    }

    /// L'alerte a besoin d'un binding qu'elle puisse remettre à `false` quand
    /// elle se referme, sinon un balayage annulé la laisserait revenir.
    private var deletionAlert: Binding<Bool> {
        Binding(get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } })
    }

    var body: some View {
        Group {
            if finished.isEmpty {
                ContentUnavailableView(
                    "Aucune partie terminée",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Les parties que vous aurez terminées s'afficheront ici, et vous pourrez y revenir pour corriger les points.")
                )
            } else {
                List {
                    ForEach(finished) { session in
                        Button { store.path.append(session.id) } label: {
                            row(session)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { pendingDeletion = session } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Historique")
        .nightBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert("Supprimer cette partie ?", isPresented: deletionAlert, presenting: pendingDeletion) { session in
            Button("Supprimer", role: .destructive) { store.deleteSession(id: session.id) }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: { _ in
            Text("La partie disparaîtra de l'historique et des statistiques. C'est irréversible.")
        }
    }

    @ViewBuilder
    private func row(_ session: ScoreSession) -> some View {
        HStack(spacing: 12) {
            GameGlyph(gameId: session.gameId, size: 24)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.gameName).font(.body.weight(.medium))
                Text(participants(session))
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if let w = session.winnerIndex {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.crownGold)
                        Text(session.entrants[w].name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// Construit la ligne « Jimmy 12 · Paul 9 » en une seule chaîne localisée,
    /// plutôt qu'en concaténant des `Text` : les scores restent alignés sur la
    /// même ligne et la troncature se fait proprement.
    private func participants(_ session: ScoreSession) -> String {
        session.entrants.indices
            .map { "\(session.entrants[$0].name) \(session.total($0))" }
            .joined(separator: " · ")
    }
}
