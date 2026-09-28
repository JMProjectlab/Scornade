import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

struct LoginView: View {
    @EnvironmentObject var store: Store
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var authError: String?
    @State private var currentNonce: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                // L'icône de l'app, posée dans la lueur braise qui l'éclaire.
                Image("LogoScornade")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color(hex: "FF5A1F").opacity(0.55), radius: 28)
                Text("Scornade").font(.jmDisplay).jmTightTracking(34)
                Text("Comptez. Gagnez. Recommencez.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                    // Firebase exige un nonce haché : il lie le jeton d'identité
                    // renvoyé par Apple à cette demande précise, ce qui empêche
                    // qu'un jeton intercepté serve à se connecter ailleurs.
                    let nonce = AppleNonce.random()
                    currentNonce = nonce
                    request.nonce = AppleNonce.sha256(nonce)
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 8) {
                    Rectangle().fill(Color.hairline).frame(height: 0.5)
                    Text("ou").font(.caption).foregroundStyle(.secondary)
                    Rectangle().fill(Color.hairline).frame(height: 0.5)
                }
                .padding(.vertical, 2)

                Button(action: signInWithGoogle) {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle")
                        Text("Se connecter avec Google").fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .foregroundStyle(Color.ink)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hairline, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isWorking)

                Button("Continuer sans compte") {
                    store.continueAsGuest()
                    dismiss()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity).frame(height: 44)
                .padding(.top, 4)

                Text("Un compte permet de retrouver vos parties sur vos autres appareils. Sans compte, tout reste sur cet appareil.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                Color.night
                RadialGradient(colors: [Color(hex: "FF5A1F").opacity(0.35), .clear],
                               center: UnitPoint(x: 0.5, y: 0.32), startRadius: 0, endRadius: 320)
            }
            .ignoresSafeArea()
        )
        .alert("Connexion impossible", isPresented: .constant(authError != nil)) {
            Button("OK") { authError = nil }
        } message: {
            Text(authError ?? "")
        }
        // Quand la vue est présentée depuis l'onglet Joueurs pour rattacher un
        // compte à une session locale, elle se referme d'elle-même une fois la
        // connexion faite. À la racine de l'app, `dismiss()` ne fait rien.
        .onChange(of: store.currentUser) { user in
            if let user, !user.isGuest { dismiss() }
        }
    }

    // MARK: Google

    private func signInWithGoogle() {
        guard FirebaseSupport.isAvailable,
              let clientID = FirebaseApp.app()?.options.clientID else {
            authError = String(localized: "La connexion Google n'est pas configurée sur cette version.",
                               locale: locale)
            return
        }
        guard let presenter = Self.topViewController() else { return }

        isWorking = true
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error {
                isWorking = false
                // Fermer la feuille Google n'est pas une erreur à signaler.
                if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
                authError = error.localizedDescription
                return
            }
            guard let googleUser = result?.user,
                  let idToken = googleUser.idToken?.tokenString else {
                isWorking = false
                authError = String(localized: "Réponse Google incomplète.", locale: locale)
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: googleUser.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { authResult, error in
                isWorking = false
                if let error {
                    authError = error.localizedDescription
                    return
                }
                let profile = googleUser.profile
                store.signIn(id: authResult?.user.uid ?? UUID().uuidString,
                             name: profile?.name ?? "Joueur Google",
                             email: profile?.email,
                             mode: .google)
            }
        }
    }

    /// Contrôleur à partir duquel présenter la feuille Google.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    // MARK: Apple

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                authError = String(localized: "Identifiants Apple non reconnus.", locale: locale)
                return
            }
            // Apple ne transmet le nom qu'à la toute première connexion : on le
            // capte ici, sinon on retombera sur le libellé générique.
            let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let displayName = name.isEmpty ? "Joueur Apple" : name

            // Le compte est désormais obligatoire : sans Firebase derrière, ouvrir
            // une session purement locale donnerait un compte qui ne synchronise
            // rien. Mieux vaut le dire que le simuler.
            guard FirebaseSupport.isAvailable,
                  let nonce = currentNonce,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                currentNonce = nil
                authError = String(localized: "La connexion n'est pas configurée sur cette version.",
                                   locale: locale)
                return
            }

            let credential = OAuthProvider.appleCredential(withIDToken: token,
                                                           rawNonce: nonce,
                                                           fullName: cred.fullName)
            Auth.auth().signIn(with: credential) { authResult, error in
                currentNonce = nil
                if let error {
                    authError = error.localizedDescription
                    return
                }
                store.signIn(id: authResult?.user.uid ?? cred.user,
                             name: displayName,
                             email: cred.email ?? authResult?.user.email,
                             mode: .apple)
            }
        case .failure(let error):
            currentNonce = nil
            // L'utilisateur qui referme la feuille Apple n'a pas besoin d'alerte.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            authError = error.localizedDescription
        }
    }
}

/// Nonce à usage unique pour « Se connecter avec Apple » via Firebase.
enum AppleNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var byte: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else { continue }
            if byte < charset.count {
                result.append(charset[Int(byte)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
