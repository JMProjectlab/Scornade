import Foundation
import StoreKit

/// Un achat reconnu.
///
/// Le document est partagé avec le site : mêmes clés, même identifiant de
/// document — c'est celui du produit. Voir `docs/assets/entitlements.js`.
struct Purchase: Identifiable, Codable, Hashable {
    /// L'identifiant du produit App Store. Sert aussi d'identifiant de document.
    var id: String
    /// Date ISO 8601, en texte, comme partout ailleurs dans ce modèle.
    var purchasedAt: String
}

/// L'achat intégré : chargement du produit, paiement, restauration.
///
/// Ce service ne décide de rien. Il traduit ce que dit StoreKit en un droit
/// d'accès écrit dans le `Store`, qui le persiste et le synchronise — et c'est
/// le `Store` que lisent les écrans.
///
/// **Le site ne vend pas** : il lit ce droit d'accès et s'arrête là. La règle
/// 3.1.1 d'Apple interdit de toute façon de renvoyer vers un paiement
/// extérieur depuis l'application.
@MainActor
final class StoreKitService: ObservableObject {

    /// Le créateur de jeu personnalisé. Non-consommable : acheté une fois,
    /// restaurable à vie, sans abonnement à tenir.
    static let creatorProductID = "com.jmprojectlab.scornade.creator"

    @Published private(set) var creator: Product?
    @Published private(set) var working = false
    @Published var failure: String?

    private weak var store: Store?
    private var updates: Task<Void, Never>?

    init() {
        // Les transactions arrivent aussi sans qu'on les demande : achat fait
        // sur un autre appareil, achat en attente validé par un parent,
        // remboursement. Cette boucle vit aussi longtemps que l'application.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.apply(update)
            }
        }
    }

    deinit { updates?.cancel() }

    /// Branche le service sur le store qui portera le droit d'accès.
    func attach(_ store: Store) { self.store = store }

    /// Va chercher la fiche du produit — libellé et prix, déjà traduits et
    /// convertis par Apple selon la boutique de l'utilisateur.
    func load() async {
        do {
            creator = try await Product.products(for: [Self.creatorProductID]).first
        } catch {
            failure = String(localized: "Impossible de joindre l'App Store.")
        }
    }

    /// Le prix tel qu'Apple veut qu'on l'affiche. Jamais écrit en dur.
    var displayPrice: String? { creator?.displayPrice }

    func buy() async {
        guard let creator else {
            failure = String(localized: "Produit indisponible pour le moment.")
            return
        }
        working = true
        defer { working = false }
        do {
            switch try await creator.purchase() {
            case .success(let verification):
                await apply(verification)
            case .userCancelled:
                failure = nil
            case .pending:
                // Achat en attente d'un tiers (Demander à acheter). Rien à
                // débloquer maintenant ; la boucle `Transaction.updates` le fera.
                failure = String(localized: "Achat en attente de validation.")
            @unknown default:
                failure = nil
            }
        } catch {
            failure = String(localized: "L'achat n'a pas abouti.")
        }
    }

    /// Restaure un achat déjà fait — obligatoire pour un non-consommable, et
    /// motif de refus classique à l'examen quand il manque.
    func restore() async {
        working = true
        defer { working = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Relit ce qu'Apple considère comme acquis pour ce compte.
    func refreshEntitlements() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.creatorProductID,
                  transaction.revocationDate == nil else { continue }
            owned = true
        }
        if owned {
            store?.grant(productID: Self.creatorProductID)
        } else {
            // Remboursé, ou jamais acheté sur ce compte Apple.
            store?.revoke(productID: Self.creatorProductID)
        }
    }

    /// Une transaction vérifiée débloque ; une transaction non vérifiée ne
    /// débloque rien et ne se termine pas.
    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.creatorProductID {
            if transaction.revocationDate == nil {
                store?.grant(productID: transaction.productID)
            } else {
                store?.revoke(productID: transaction.productID)
            }
        }
        await transaction.finish()
    }
}
