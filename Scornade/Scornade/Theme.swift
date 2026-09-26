import SwiftUI
import UIKit

// MARK: - Couleurs
//
// Thème « nuit et braise », repris de l'icône : un fond nuit-violet, des
// surfaces violettes à peine plus claires, et l'orange braise comme seul
// accent, réservé à ce qui est actionnable ou sélectionné — jamais décoratif.
// L'app s'affiche toujours en sombre (voir ScornadeApp) ; les valeurs claires
// restent définies pour les aperçus Xcode et un éventuel retour du mode clair.

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// Couleur adaptative clair/sombre (façon Asset Catalog, définie en code).
    init(light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }

    // Neutres du thème.
    static let ink = Color(light: Color(hex: "1A1033"), dark: Color(hex: "F7F4FF"))
    static let inkSecondary = Color(light: Color(hex: "6B6485"), dark: Color(hex: "D4CDEF"))
    /// Fond d'écran : la nuit de l'icône.
    static let night = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "0F0A24"))
    /// Surface des cartes et des champs, posée sur `night`.
    static let cloud = Color(light: Color(hex: "F5F2FC"), dark: Color(hex: "2A2060"))
    /// Surface un cran au-dessus de `cloud` (champ dans une carte).
    static let cloudRaised = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "3A2E7A"))
    static let hairline = Color(light: Color(hex: "E2DCF0"), dark: Color(hex: "5B4F99"))

    // L'accent : violet en clair, braise en sombre. En sombre, le texte blanc
    // des boutons pleins y garde un contraste de 3,3:1, suffisant pour leur
    // libellé en gras de 17 pt (seuil « grand texte » du WCAG).
    static let brand = Color(light: Color(hex: "6D28D9"), dark: Color(hex: "F2600C"))
    /// Fond teinté d'un élément sélectionné ou actif (l'accent, très dilué).
    static let brandLight = Color.brand.opacity(0.16)
    /// Texte posé sur `brandLight`.
    static let brandDark = Color(light: Color(hex: "5B21B6"), dark: Color(hex: "FF8A3D"))

    // Retours sémantiques (contrat réussi / chuté, bust, saisie invalide).
    // La charte ne définit ni vert ni rouge : on s'appuie sur les couleurs
    // système d'Apple, déjà adaptatives et cohérentes avec le reste d'iOS.
    static let success = Color(uiColor: .systemGreen)
    static let successLight = Color(uiColor: .systemGreen).opacity(0.12)
    static let danger = Color(uiColor: .systemRed)
    static let dangerLight = Color(uiColor: .systemRed).opacity(0.12)
    static let gold = Color(uiColor: .systemOrange)
    static let crownGold = Color(uiColor: .systemYellow)

    // Jeux à deux équipes (Belote, Coinche) : l'Équipe 1 prend le bleu, l'Équipe 2
    // prend l'encre — les deux piliers de la charte, sans introduire de teinte tierce.
    static let teamTwo = Color.ink
    static let teamTwoLight = Color.ink.opacity(0.08)
    static let teamTwoDark = Color.ink
}

// MARK: - Typographie
//
// Aucune police n'est embarquée : la pile système affiche SF Pro sur iOS, comme
// le prescrit la charte. Titres jamais plus gras que semi-bold, chasse serrée,
// et chiffres tabulaires pour que les scores ne sautent pas d'une manche à l'autre.

extension Font {
    static let jmDisplay = Font.system(size: 34, weight: .semibold)
    static let jmTitle = Font.system(size: 32, weight: .semibold)
    static let jmSubtitle = Font.system(size: 22, weight: .semibold)
    static let jmBody = Font.system(size: 17)
    static let jmCaption = Font.system(size: 13)

    /// Chiffres de score : SF Pro à chasse tabulaire.
    static func jmScore(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// Lignes de données compactes (historique, ratios) : SF Mono.
    static func jmData(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// Fond « nuit » sous tout l'écran, y compris derrière une liste ou un
    /// formulaire, dont le fond système gris est masqué.
    func nightBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.night.ignoresSafeArea())
    }

    /// Chasse serrée des titres de la charte (−0,02 em).
    func jmTightTracking(_ size: CGFloat) -> some View {
        tracking(size * -0.02)
    }
}

// MARK: - Couleurs joueurs
//
// Les avatars doivent rester distinguables entre eux : c'est de l'information, pas
// de la décoration. On s'appuie sur les teintes système d'Apple plutôt que sur des
// pastels sur mesure, pour rester dans le registre natif de la charte.

struct Palette {
    private static let hues: [Color] = [
        Color(uiColor: .systemBlue),
        Color(uiColor: .systemTeal),
        Color(uiColor: .systemOrange),
        Color(uiColor: .systemIndigo),
        Color(uiColor: .systemPink),
        Color(uiColor: .systemPurple),
    ]

    static let pairs: [(bg: Color, fg: Color)] = hues.map { (bg: $0.opacity(0.14), fg: $0) }
    static let bars: [Color] = hues

    static func pair(_ i: Int) -> (bg: Color, fg: Color) { pairs[i % pairs.count] }
    static func bar(_ i: Int) -> Color { bars[i % bars.count] }
}

extension String {
    var initials: String {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(2)).uppercased()
    }
}
