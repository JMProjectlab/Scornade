import SwiftUI
import StoreKit
import GoogleSignIn

@main
struct ScornadeApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("sm.languagePreference") private var languagePreference = "system"

    init() {
        // Doit précéder la création du Store, qui interroge Auth dès son init.
        // L'autoclosure d'un @StateObject n'est évaluée qu'au premier accès au
        // corps de la vue, donc après ce init : l'ordre est garanti.
        FirebaseSupport.configureIfPossible()
    }

    // "system" laisse SwiftUI suivre la langue de l'appareil (comportement par défaut).
    private var localeOverride: Locale? {
        languagePreference == "system" ? nil : Locale(identifier: languagePreference)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.currentUser == nil {
                    LoginView()
                } else {
                    HomeView()
                }
            }
            .modifier(ReviewPrompt())
            .environmentObject(store)
            .tint(Color.brand)
            // Le thème nuit et braise de l'icône vaut pour toute l'app.
            .preferredColorScheme(.dark)
            .environment(\.locale, localeOverride ?? Locale.autoupdatingCurrent)
            .onOpenURL { url in
                // Retour de la feuille de connexion Google.
                _ = GIDSignIn.sharedInstance.handle(url)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.reloadFromCloud() }
        }
    }
}

// MARK: - Demande d'avis

/// Demande un avis App Store juste après une partie terminée — le moment où
/// l'app vient de rendre service —, jamais au lancement. Une seule demande par
/// version, et à partir de la deuxième partie terminée, pour ne pas solliciter
/// quelqu'un qui découvre l'app. iOS plafonne de toute façon l'affichage à
/// trois fois par an et peut ne rien montrer.
private struct ReviewPrompt: ViewModifier {
    @EnvironmentObject private var store: Store
    @Environment(\.requestReview) private var requestReview
    /// Parties terminées déjà vues. -1 : premier lancement, rien de mesuré.
    @AppStorage("sm.review.finishedSeen") private var finishedSeen = -1
    @AppStorage("sm.review.askedVersion") private var askedVersion = ""

    private var finishedCount: Int { store.sessions.filter(\.isFinished).count }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Les parties déjà terminées avant cette version ne déclenchent rien.
                if finishedSeen < 0 { finishedSeen = finishedCount }
            }
            .onChange(of: finishedCount) { count in
                let isNewFinish = count > finishedSeen
                finishedSeen = max(finishedSeen, count)
                guard isNewFinish, count >= 2, askedVersion != appVersion else { return }
                askedVersion = appVersion
                Task { @MainActor in
                    // Laisser le temps d'afficher le vainqueur avant la demande.
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    requestReview()
                }
            }
    }
}
