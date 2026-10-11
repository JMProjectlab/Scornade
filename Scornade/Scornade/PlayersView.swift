import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins
import VisionKit

struct PlayersView: View {
    @EnvironmentObject var store: Store
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var showDeleteConfirm = false
    @State private var showLogin = false
    @State private var showFuse = false
    @State private var showMyCode = false
    @State private var showScanner = false
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

            Section {
                if store.myInvite != nil {
                    Button { showMyCode = true } label: {
                        Label("Afficher mon code joueur", systemImage: "qrcode")
                    }
                } else {
                    Text("Connectez-vous pour obtenir votre code joueur : les autres vous ajoutent en le scannant.")
                        .font(.footnote).foregroundStyle(Color.inkSecondary)
                }
                Button { showScanner = true } label: {
                    Label("Scanner un code joueur", systemImage: "qrcode.viewfinder")
                }
            } header: {
                Text("Code joueur")
            } footer: {
                Text("Scanner le code d'un autre joueur l'ajoute à vos joueurs sans rien taper, relié à son compte.")
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
                            HStack(spacing: 6) {
                                Text(player.name)
                                if player.linkedUid != nil {
                                    Image(systemName: "link")
                                        .font(.caption)
                                        .foregroundStyle(Color.brand)
                                        .accessibilityLabel("Relié à son compte")
                                }
                            }
                            if let email = player.email {
                                Text(email).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx { store.removePlayer(store.players[i]) }
                }
                if store.players.count >= 2 {
                    Button { showFuse = true } label: {
                        Label("Fusionner deux fiches…", systemImage: "arrow.triangle.merge")
                    }
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
        .sheet(isPresented: $showFuse) {
            FusePlayersSheet().environmentObject(store)
        }
        .sheet(isPresented: $showMyCode) {
            if let invite = store.myInvite { MyPlayerCodeSheet(invite: invite) }
        }
        .sheet(isPresented: $showScanner) {
            ScanPlayerSheet().environmentObject(store)
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

/// Réunit deux fiches qui désignent la même personne, par exemple « Manon »
/// créée une fois sous chaque compte.
private struct FusePlayersSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var keptID: UUID?
    @State private var duplicateID: UUID?
    @State private var confirm = false

    private var kept: Player? { keptID.flatMap { store.player(id: $0) } }
    private var duplicate: Player? { duplicateID.flatMap { store.player(id: $0) } }
    private var canFuse: Bool { kept != nil && duplicate != nil && keptID != duplicateID }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Fiche à garder", selection: $keptID) {
                        Text("Choisir").tag(UUID?.none)
                        ForEach(store.players) { Text(label($0)).tag(Optional($0.id)) }
                    }
                    Picker("Fiche à fusionner", selection: $duplicateID) {
                        Text("Choisir").tag(UUID?.none)
                        ForEach(store.players.filter { $0.id != keptID }) {
                            Text(label($0)).tag(Optional($0.id))
                        }
                    }
                } footer: {
                    Text("Les parties et les statistiques de la seconde fiche passent sur la première, puis la seconde est supprimée.")
                }
                Section {
                    Button("Fusionner") { confirm = true }
                        .disabled(!canFuse)
                }
            }
            .navigationTitle("Fusionner deux fiches")
            .nightBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .alert("Fusionner ces fiches ?", isPresented: $confirm) {
                Button("Fusionner", role: .destructive) {
                    if let kept, let duplicate { store.fusePlayer(duplicate, into: kept) }
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(duplicate?.name ?? "") » rejoint « \(kept?.name ?? "") ». Cette action ne s'annule pas.")
            }
        }
    }

    /// Le nom seul ne suffit pas à distinguer deux « Manon » : l'e-mail, quand
    /// il existe, et le nombre de parties font la différence.
    private func label(_ p: Player) -> String {
        let games = store.sessions.filter { $0.entrants.contains { $0.playerIds.contains(p.id) } }.count
        var parts = [p.name]
        if let email = p.email, !email.isEmpty { parts.append(email) }
        parts.append(games == 1 ? "1 partie" : "\(games) parties")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Code joueur

/// Mon code joueur en grand, à faire scanner par un autre téléphone.
struct MyPlayerCodeSheet: View {
    let invite: PlayerInvite
    @Environment(\.dismiss) private var dismiss

    init(invite: PlayerInvite) { self.invite = invite }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Faites scanner ce code par un autre joueur : vous apparaîtrez dans ses joueurs, relié à votre compte. S'il n'a pas Scornade, le code l'y emmène.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                    if let image = QRCodeImage.make(invite.url.absoluteString) {
                        // Le blanc autour du code est voulu : un lecteur a besoin
                        // de cette marge claire pour trouver le motif.
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .padding(18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .frame(maxWidth: 300)
                            .accessibilityLabel("QR code de \(invite.name)")
                    }
                    VStack(spacing: 4) {
                        Text(invite.name).font(.jmSubtitle)
                        if let email = invite.email {
                            Text(email).font(.footnote).foregroundStyle(Color.inkSecondary)
                        }
                    }
                    ShareLink(item: invite.url) {
                        Label("Envoyer le lien", systemImage: "square.and.arrow.up")
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Mon code joueur")
            .nightBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

enum QRCodeImage {
    /// Code QR net à toute taille : chaque module vaut 12 pixels, et l'image
    /// s'affiche sans lissage.
    static func make(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Scanne le code d'un autre joueur, puis propose la fiche à relier.
struct ScanPlayerSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    /// Appelé avec la fiche créée ou reliée (l'écran de nouvelle partie la
    /// sélectionne aussitôt).
    let onLinked: (Player) -> Void

    @State private var cameraAllowed: Bool?
    @State private var invite: PlayerInvite?
    @State private var targetID: UUID?
    @State private var message: String?

    init(onLinked: @escaping (Player) -> Void = { _ in }) {
        self.onLinked = onLinked
    }

    var body: some View {
        NavigationStack {
            Group {
                if let invite {
                    confirmation(invite)
                } else if !DataScannerViewController.isSupported {
                    notice("Le scan n'est pas disponible sur cet appareil.")
                } else if cameraAllowed == false {
                    notice("Scornade n'a pas accès à l'appareil photo. Autorisez-le dans Réglages › Scornade.")
                } else if cameraAllowed == true {
                    QRScanner { handle($0) }
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .bottom) {
                            Text(message ?? "Visez le code joueur affiché sur l'autre téléphone.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Color.cloud, in: Capsule())
                                .padding(.bottom, 32)
                        }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Scanner un code joueur")
            .nightBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            // Première utilisation : iOS pose ici la question de l'appareil photo.
            .task { cameraAllowed = await AVCaptureDevice.requestAccess(for: .video) }
        }
    }

    private func handle(_ text: String) {
        guard invite == nil else { return }
        guard let found = PlayerInvite(string: text) else {
            message = "Ce code n'est pas un code joueur Scornade."
            return
        }
        if found.uid == store.myInvite?.uid {
            message = "C'est votre propre code."
            return
        }
        targetID = store.bestMatch(for: found)?.id
        invite = found
    }

    private func confirmation(_ invite: PlayerInvite) -> some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Avatar(name: invite.name, colorIndex: 0)
                    VStack(alignment: .leading) {
                        Text(invite.name)
                        if let email = invite.email {
                            Text(email).font(.caption).foregroundStyle(Color.inkSecondary)
                        }
                    }
                }
            }
            Section {
                Picker("Fiche", selection: $targetID) {
                    Text("Nouvelle fiche « \(invite.name) »").tag(UUID?.none)
                    ForEach(store.players.filter { $0.linkedUid == nil || $0.linkedUid == invite.uid }) { p in
                        Text(p.email.map { "\(p.name) · \($0)" } ?? p.name).tag(Optional(p.id))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Relier à")
            } footer: {
                Text("Choisissez sa fiche si elle existe déjà : ses parties restent les mêmes, sans doublon.")
            }
            Section {
                Button("Ajouter à mes joueurs") {
                    let player = store.link(invite, to: targetID.flatMap { store.player(id: $0) })
                    onLinked(player)
                    dismiss()
                }
            }
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.inkSecondary)
            .padding(32)
    }
}

/// Lecteur de QR code de VisionKit (iOS 16), réduit au strict nécessaire.
struct QRScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced,
                                                isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let code) = item, let text = code.payloadStringValue {
                    onCode(text)
                    return
                }
            }
        }
    }
}
