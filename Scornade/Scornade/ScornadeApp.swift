import SwiftUI
import GoogleSignIn

@main
struct ScornadeApp: App {
    @StateObject private var store = Store()
    @StateObject private var storeKit = StoreKitService()
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
            .environmentObject(store)
            .environmentObject(storeKit)
            // Le service d'achat écrit le droit d'accès dans le store ; il ne
            // décide de rien lui-même. On les attache ici plutôt qu'au
            // démarrage : les deux objets existent alors pour de bon.
            .task {
                storeKit.attach(store)
                await storeKit.refreshEntitlements()
            }
            .tint(Color.brand)
            .environment(\.locale, localeOverride ?? Locale.autoupdatingCurrent)
            .onOpenURL { url in
                // Retour de la feuille de connexion Google.
                _ = GIDSignIn.sharedInstance.handle(url)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                store.reloadFromCloud()
                // Ce qu'Apple considère comme acquis fait foi : un achat fait
                // ailleurs, ou remboursé, se reflète au retour dans l'app.
                Task { await storeKit.refreshEntitlements() }
            }
        }
    }
}
