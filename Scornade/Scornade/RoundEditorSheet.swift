import SwiftUI

/// Corrige les points d'une manche déjà jouée.
///
/// La saisie se fait au clavier, une ligne par joueur, préremplie avec ce qui
/// avait été compté. Un champ vide vaut zéro plutôt que d'invalider la
/// correction : c'est la façon la plus courante d'écrire « ce joueur n'a rien
/// marqué ».
struct RoundEditorSheet: View {
    let entrants: [Entrant]
    let roundNumber: Int
    /// Vrai aux jeux à contrat, où les points sont calculés depuis une donne
    /// détaillée. Corriger les points à la main fait perdre ce détail.
    let losesDetail: Bool
    let onSave: ([Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fields: [String]

    init(entrants: [Entrant],
         roundNumber: Int,
         deltas: [Int],
         losesDetail: Bool = false,
         onSave: @escaping ([Int]) -> Void) {
        self.entrants = entrants
        self.roundNumber = roundNumber
        self.losesDetail = losesDetail
        self.onSave = onSave
        _fields = State(initialValue: entrants.indices.map { i in
            String(deltas.indices.contains(i) ? deltas[i] : 0)
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Points de la manche") {
                    ForEach(entrants.indices, id: \.self) { i in
                        HStack {
                            Text(entrants[i].name).lineLimit(1)
                            Spacer()
                            TextField("0", text: binding(for: i))
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }
                    }
                }

                if losesDetail {
                    Section {
                        Label("Le détail de la donne (contrat, bouts, annonces) sera perdu : seuls les points corrigés seront conservés.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .navigationTitle("Manche \(roundNumber)")
            .nightBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(fields.map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 })
                        dismiss()
                    }
                }
            }
        }
    }

    /// `fields` est dimensionné dans `init`, mais on lit et écrit malgré tout
    /// avec des bornes : un joueur retiré de la partie entre-temps ferait
    /// autrement planter la feuille à l'ouverture.
    private func binding(for i: Int) -> Binding<String> {
        Binding(
            get: { fields.indices.contains(i) ? fields[i] : "" },
            set: { if fields.indices.contains(i) { fields[i] = $0 } }
        )
    }
}
