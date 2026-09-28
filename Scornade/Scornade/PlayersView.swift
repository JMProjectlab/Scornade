import SwiftUI

struct PlayersView: View {
    @EnvironmentObject var store: Store
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var showDeleteConfirm = false
    @State private var showLogin = false
    @AppStorage("sm.languagePreference") private var languagePreference = "system"
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section("Langue") {
                Picker("Langue", selection: $languagePreference) {
                    Text("Système (iOS)").tag("system")
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                }
                .pickerStyle(.menu)
            }

            Section("Ajouter un joueur") {
                TextField("Nom", text: $newName)
                TextField("E-mail (optionnel, pour la synchro)", text: $newEmail)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                Button("Ajouter") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    store.addPlayer(name: trimmed, email: newEmail.isEmpty ? nil : newEmail)
                    newName = ""; newEmail = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Joueurs") {
                ForEach(store.players) { player in
                    HStack(spacing: 12) {
                        Avatar(name: player.name, colorIndex: player.colorIndex)
                        VStack(alignment: .leading) {
                            Text(player.name)
                            if let email = player.email {
                                Text(email).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx { store.removePlayer(store.players[i]) }
                }
            }
            Section("Compte") {
                if let u = store.currentUser {
                    HStack {
                        Text(u.isGuest ? "Mode local" : "Connecté")
                        Spacer()
                        Text(accountLabel(u)).foregroundStyle(.secondary)
                    }
                }
                // Sans compte, la seule action utile est d'en créer un ; se
                // « déconnecter » d'une session locale n'aurait aucun sens.
                if store.currentUser?.isGuest ?? true {
                    Button { showLogin = true } label: {
                        Text("Se connecter pour synchroniser")
                    }
                } else {
                    Button(role: .destructive) { store.signOut() } label: {
                        Text("Se déconnecter")
                    }
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Text("Supprimer mes données")
                }
            }

            // Apple exige un lien vers la politique de confidentialité accessible
            // depuis l'application elle-même, pas seulement depuis la fiche
            // App Store (règle 5.1.1).
            Section("À propos") {
                Link(destination: Self.websiteURL) {
                    HStack {
                        Text("Site web")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Link(destination: Self.privacyPolicyURL) {
                    HStack {
                        Text("Politique de confidentialité")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
        .navigationTitle("Joueurs")
        .nightBackground()
        .alert("Supprimer mes données ?", isPresented: $showDeleteConfirm) {
            Button("Supprimer", role: .destructive) { store.deleteAllData() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action efface tous vos joueurs, vos parties et votre compte, sur cet appareil et sur le serveur. Elle est irréversible.")
        }
        .sheet(isPresented: $showLogin) {
            LoginView().environmentObject(store)
        }
    }

    /// Le chemin suit le nom du dépôt GitHub Pages ; il change si le dépôt est
    /// renommé. `URL(string:)` ne peut pas échouer sur une constante littérale.
    private static let websiteURL = URL(
        string: "https://jmprojectlab.github.io/Scornade/"
    )!

    private static let privacyPolicyURL = URL(
        string: "https://jmprojectlab.github.io/Scornade/politique-de-confidentialite.html"
    )!

    private func accountLabel(_ u: UserAccount) -> String {
        switch u.mode {
        case .apple: return String(localized: "\(u.name) · Apple", locale: locale)
        case .google: return String(localized: "\(u.name) · Google", locale: locale)
        case .guest: return String(localized: "Sur cet appareil", locale: locale)
        }
    }
}
