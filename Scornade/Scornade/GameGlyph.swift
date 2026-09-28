import SwiftUI
import UIKit

/// Pictogramme d'un jeu.
///
/// Les jeux édités (Uno, Skyjo, Papayoo, Scrabble, Dominos, Mille Bornes…) ont des
/// logos déposés qu'on ne peut pas embarquer : on dessine à la place un motif qui
/// évoque le matériel du jeu — un pli de cartes, une grille, une tuile — sans
/// reprendre aucun élément de marque. Les autres jeux gardent leur SF Symbol.
struct GameGlyph: View {
    let gameId: String
    var size: CGFloat = 22
    var tint: Color = .inkSecondary

    var body: some View {
        Group {
            switch gameId {
            case "uno":         fannedCards
            case "skyjo":       cardGrid
            case "papayoo":     suitCard
            case "scrabble":    letterTile
            case "dominos":     dominoTile
            case "millebornes": milestone
            case "dekal":       shiftedGrid
            case "phase10":     phaseList
            case "cinqrois":    crown
            default:            fallbackSymbol
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(tint)
    }

    // Échelle : tous les tracés sont pensés dans une boîte de 22 pt.
    private var u: CGFloat { size / 22 }

    /// Le pictogramme par défaut : le SF Symbol déclaré au catalogue.
    ///
    /// Ce nom peut venir de Firestore, donc être n'importe quoi. `Image(systemName:)`
    /// ne dessine rien du tout devant un nom inconnu — pas de point
    /// d'interrogation, une case vide — et un jeu sans pictogramme passe pour
    /// un défaut d'affichage. On vérifie donc que le symbole existe vraiment,
    /// et on retombe sinon sur un dé, qui vaut pour n'importe quel jeu.
    private static let defaultSymbol = "dice"

    private var fallbackSymbol: some View {
        let declared = GameCatalog.game(id: gameId)?.symbol
        let name = declared.flatMap { UIImage(systemName: $0) != nil ? $0 : nil }
            ?? Self.defaultSymbol
        return Image(systemName: name)
            .font(.system(size: size * 0.86))
    }

    /// Uno — trois cartes en éventail.
    private var fannedCards: some View {
        ZStack {
            card(w: 9, h: 13).rotationEffect(.degrees(-16)).offset(x: -4 * u)
            card(w: 9, h: 13).rotationEffect(.degrees(16)).offset(x: 4 * u)
            card(w: 9, h: 13, filled: true)
        }
    }

    /// Skyjo — le tableau de cartes face visible.
    private var cardGrid: some View {
        VStack(spacing: 1.6 * u) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 1.6 * u) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.8 * u)
                            .fill(tint)
                            .frame(width: 3.6 * u, height: 4.4 * u)
                    }
                }
            }
        }
    }

    /// Papayoo — une carte avec ses points (et non un dé : c'est un jeu de plis).
    private var suitCard: some View {
        ZStack {
            card(w: 13, h: 17)
            VStack(spacing: 2 * u) {
                pip
                HStack(spacing: 2 * u) { pip; pip }
            }
        }
    }

    /// Scrabble — une tuile lettre avec sa valeur.
    private var letterTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.4 * u)
                .stroke(tint, lineWidth: 1.5 * u)
                .frame(width: 17 * u, height: 17 * u)
            Text("A")
                .font(.system(size: 9.5 * u, weight: .semibold))
                .offset(x: -1 * u, y: -0.5 * u)
            Text("1")
                .font(.system(size: 5 * u, weight: .semibold))
                .offset(x: 4.5 * u, y: 4 * u)
        }
    }

    /// Dominos — une tuile et ses points.
    private var dominoTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2 * u)
                .stroke(tint, lineWidth: 1.5 * u)
                .frame(width: 12 * u, height: 18 * u)
            Rectangle()
                .fill(tint)
                .frame(width: 9 * u, height: 1.2 * u)
            VStack(spacing: 3.4 * u) {
                HStack(spacing: 2.4 * u) { pip; pip }
                HStack(spacing: 2.4 * u) { pip; pip }
            }
        }
    }

    /// Mille Bornes — une borne kilométrique.
    private var milestone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4 * u)
                .stroke(tint, lineWidth: 1.5 * u)
                .frame(width: 12 * u, height: 17 * u)
            Rectangle()
                .fill(tint)
                .frame(width: 10.5 * u, height: 1.4 * u)
                .offset(y: -2.5 * u)
            Text("1000")
                .font(.system(size: 4.2 * u, weight: .semibold))
                .offset(y: 2.6 * u)
        }
    }

    /// Dékal — la carte qu'on glisse par le côté pour décaler une rangée.
    ///
    /// La grille seule ressemblait trop à celle de Skyjo : c'est le décalage
    /// qui fait le jeu, donc c'est lui qu'on dessine.
    private var shiftedGrid: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            RoundedRectangle(cornerRadius: 0.9 * u)
                .stroke(tint, lineWidth: 1.4 * u)
                .frame(width: 4.4 * u, height: 4.4 * u)
                .offset(x: 0.7 * u, y: 8.8 * u)
            ForEach(0..<9, id: \.self) { i in
                let row = i / 3, col = i % 3
                RoundedRectangle(cornerRadius: 0.9 * u)
                    .fill(tint)
                    .frame(width: 4.4 * u, height: 4.4 * u)
                    .offset(x: (6.7 + CGFloat(col) * 5.0) * u,
                            y: (3.4 + CGFloat(row) * 5.4) * u)
            }
        }
    }

    /// Phase 10 — la liste des phases à franchir, sur une carte.
    private var phaseList: some View {
        ZStack {
            card(w: 13, h: 17)
            VStack(alignment: .leading, spacing: 1.9 * u) {
                bar(8)
                bar(8)
                bar(5)
            }
        }
    }

    /// Les Cinq Rois — une couronne à cinq pointes.
    private var crown: some View {
        Path { p in
            p.move(to: CGPoint(x: 4 * u, y: 17 * u))
            p.addLine(to: CGPoint(x: 4 * u, y: 8 * u))
            p.addLine(to: CGPoint(x: 7.5 * u, y: 11.5 * u))
            p.addLine(to: CGPoint(x: 11 * u, y: 5.5 * u))
            p.addLine(to: CGPoint(x: 14.5 * u, y: 11.5 * u))
            p.addLine(to: CGPoint(x: 18 * u, y: 8 * u))
            p.addLine(to: CGPoint(x: 18 * u, y: 17 * u))
            p.closeSubpath()
        }
        .fill(tint)
    }

    // MARK: Briques de dessin

    private func bar(_ w: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 0.7 * u)
            .fill(tint)
            .frame(width: w * u, height: 1.4 * u)
    }


    private var pip: some View {
        Circle().fill(tint).frame(width: 2.4 * u, height: 2.4 * u)
    }

    private func card(w: CGFloat, h: CGFloat, filled: Bool = false) -> some View {
        Group {
            if filled {
                RoundedRectangle(cornerRadius: 1.8 * u)
                    .fill(tint)
                    .frame(width: w * u, height: h * u)
            } else {
                RoundedRectangle(cornerRadius: 1.8 * u)
                    .stroke(tint, lineWidth: 1.5 * u)
                    .frame(width: w * u, height: h * u)
            }
        }
    }
}
