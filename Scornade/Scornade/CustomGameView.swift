import SwiftUI

/// Où mène l'écran de création : un jeu à modifier, ou rien pour en créer un.
///
/// `NavigationPath` accepte n'importe quel `Hashable` ; ce type-là évite de
/// confondre « ouvrir le créateur » avec « ouvrir un jeu », qui voyagent tous
/// les deux dans la même pile.
struct CustomGameRoute: Hashable {
    var editing: String?
}

/// Créateur de jeu personnalisé.
///
/// L'écran ne propose que des réglages, jamais un moteur nouveau : compter des
/// points autrement, c'est du code, et du code ne se saisit pas dans un
/// formulaire. Ce que l'utilisateur décrit ici, c'est **comment se termine la
/// partie** et **qui la gagne** — le reste, l'application sait déjà le tenir.
struct CustomGameView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CustomGame
    @State private var errors: [String] = []
    @State private var confirmingDelete = false

    private let editingID: String?

    init(route: CustomGameRoute, existing: CustomGame?) {
        editingID = existing?.id ?? route.editing
        _draft = State(initialValue: existing ?? CustomGame.blank())
    }

    private var isEditing: Bool { editingID != nil }

    /// Aux manches gagnées, l'objectif se compte en petites unités : une belle
    /// se joue en 3, pas en 50.
    private var step: Int {
        switch draft.engine {
        case "manche": return 1
        case "countdown": return 100
        default: return draft.target > 0 && draft.target < 50 ? 5 : 50
        }
    }

    private var engineHelp: String {
        CustomGame.engines.first { $0.key == draft.engine }?.help ?? ""
    }

    var body: some View {
        Form {
            if !errors.isEmpty {
                Section {
                    ForEach(errors, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.danger)
                            .font(.subheadline)
                    }
                }
            }

            Section("Nom") {
                TextField("Belote de mon grand-père", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: draft.name) { _ in errors = [] }
            }

            Section("Pictogramme") {
                HStack(spacing: 10) {
                    ForEach(CustomGame.symbols, id: \.self) { key in
                        SymbolChip(key: key, selected: draft.symbol == key) {
                            draft.symbol = key
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                Picker("Comment on compte", selection: $draft.engine) {
                    ForEach(CustomGame.engines, id: \.key) { engine in
                        Text(engine.label).tag(engine.key)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.engine) { engine in adjustTarget(for: engine) }
                Text(engineHelp).font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Comment on compte")
            }

            Section("Format") {
                Toggle("Deux équipes", isOn: $draft.team)
            }

            Section("Objectif") {
                Stepper(value: $draft.target, in: 0...10000, step: step) {
                    HStack {
                        Text(targetLabel)
                        Spacer()
                        Text(draft.engine == "countdown" ? "on descend jusqu'à zéro"
                             : (draft.high ? "le + haut gagne" : "le + bas gagne"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // Un compte à rebours gagne forcément en descendant : proposer le
            // contraire décrirait une partie que le moteur ne sait pas compter.
            if draft.engine != "countdown" {
                Section("Qui gagne") {
                    Picker("Qui gagne", selection: $draft.high) {
                        Text("Le plus haut score").tag(true)
                        Text("Le plus bas score").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                Stepper(value: $draft.roundLimit, in: 0...99) {
                    Text(draft.roundLimit == 0 ? "Libre" : "\(draft.roundLimit) manches")
                }
            } header: {
                Text("Nombre de manches")
            } footer: {
                Text("Fixé, la partie s'arrête d'elle-même au bout du compte.")
            }

            Section("Règles (facultatif)") {
                TextEditor(text: $draft.rules)
                    .frame(minHeight: 110)
            }

            Section {
                Button(isEditing ? "Enregistrer" : "Créer le jeu") { save() }
                    .frame(maxWidth: .infinity)
            }

            if isEditing {
                Section {
                    Button("Supprimer ce jeu", role: .destructive) { confirmingDelete = true }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("Les parties déjà jouées avec lui sont conservées.")
                }
            }
        }
        .navigationTitle(isEditing ? "Modifier le jeu" : "Créer un jeu")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Supprimer ce jeu ?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                if let editingID { store.deleteCustomGame(id: editingID) }
                store.popToRoot()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Les parties déjà jouées avec lui sont conservées.")
        }
    }

    private var targetLabel: String {
        if draft.target == 0 { return "Fin de partie libre" }
        return draft.engine == "manche" ? "\(draft.target) manches gagnées" : "\(draft.target) points"
    }

    /// Changer de moteur change l'ordre de grandeur de l'objectif : 501 à
    /// retrancher, 3 manches à gagner. Un objectif déjà plausible n'est pas
    /// touché — seulement celui qui n'aurait aucun sens sur le nouveau moteur.
    private func adjustTarget(for engine: String) {
        errors = []
        switch engine {
        case "countdown":
            draft.high = false
            if draft.target < 100 { draft.target = 501 }
        case "manche":
            if draft.target > 21 { draft.target = 3 }
        default:
            if draft.target > 0, draft.target < 21 { draft.target = 500 }
        }
    }

    private func save() {
        let found = draft.errors(among: store.customGames)
        guard found.isEmpty else { errors = found; return }
        let saved = store.saveCustomGame(draft)
        // On repart de l'écran de mise en place du jeu, qu'il vienne d'être
        // créé ou modifié : c'est là qu'on voulait aller, et cela reconstruit la
        // vue avec les nouveaux réglages plutôt que de revenir sur les anciens.
        store.path = NavigationPath()
        store.path.append(saved.game)
    }
}

/// Une pastille de pictogramme, dans le style des filtres de l'accueil.
private struct SymbolChip: View {
    let key: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: CustomGame.systemImage(for: key))
                .font(.system(size: 18))
                .frame(width: 44, height: 40)
                .background(selected ? Color.brandLight : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? Color.brandDark : Color.inkSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? Color.brand : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pictogramme \(key)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
