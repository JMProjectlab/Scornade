#!/usr/bin/env swift
// Regénère l'image de partage du site (docs/assets/img/partage.png, 1200×630)
// avec la vraie police SF Pro, installée sur le Mac.
//
// Pourquoi un script Mac : l'image publiée a été dessinée sur un serveur
// Linux, sans SF Pro, et son texte y est tombé en Liberation Sans. SF Pro
// ne s'embarque pas ailleurs qu'un appareil Apple (licence) ; on la dessine
// donc là où elle est installée.
//
// Lancer, depuis la racine du dépôt :
//     swift scripts/image-de-partage.swift
// Seul prérequis : Xcode (ou ses outils en ligne de commande).
//
// Les couleurs et la mise en page reprennent celles de l'image actuelle :
// fond nuit-violet, icône de l'app à gauche, titre, sous-titre, jeux, et la
// pastille en dégradé braise.

import AppKit

let W = 1200, H = 630
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconURL = root.appendingPathComponent("Scornade/Scornade/Assets.xcassets/AppIcon.appiconset/scornade_icon_1024.png")
let outURL = root.appendingPathComponent("docs/assets/img/partage.png")

func hex(_ s: String, _ a: CGFloat = 1) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

func linear(_ cg: CGContext, _ colors: [NSColor], _ stops: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: colors.map(\.cgColor) as CFArray, locations: stops)!
    cg.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),   // SF Pro
        .foregroundColor: color,
        .kern: kern,
    ])
}

guard let icon = NSImage(contentsOf: iconURL) else {
    fatalError("Icône introuvable : \(iconURL.path)")
}

// Toile en pixels exacts (pas de @2x), repère retourné : y vers le bas,
// comme en CSS, pour garder les cotes de l'image d'origine.
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
cg.translateBy(x: 0, y: CGFloat(H))
cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

// Fond : dégradé nuit-violet à 135°.
linear(cg, [hex("3B1D8F"), hex("5B1A8C"), hex("1A0B3D")], [0, 0.5, 1],
       from: .zero, to: CGPoint(x: W, y: H))

// Icône : 360 px, coins de 81 px, ombre portée.
let iconRect = NSRect(x: 90, y: (H - 360) / 2, width: 360, height: 360)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 81, yRadius: 81)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = hex("001E46", 0.35)
shadow.shadowBlurRadius = 60
// Les ombres ignorent le repère retourné : une hauteur négative les porte vers le bas.
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.set()
hex("1A0B3D").setFill()
iconPath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
iconPath.addClip()
icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1,
          respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
NSGraphicsContext.restoreGraphicsState()

// Bloc de texte, centré verticalement à droite de l'icône.
let title = text("Scornade", size: 84, weight: .bold, color: .white, kern: -2)
let subtitle = text("Compteur de points", size: 40, weight: .regular, color: NSColor(white: 1, alpha: 0.95))
let games = ["Belote, coinche, tarot, Yam's,", "Mölkky et plus de 20 jeux"]
    .map { text($0, size: 30, weight: .regular, color: NSColor(white: 1, alpha: 0.85)) }
let pillLabel = text("Gratuit sur iPhone et sur le web", size: 26, weight: .bold, color: hex("140F2E"))

let gamesLine: CGFloat = 30 * 1.35
let pillH = pillLabel.size().height + 24
let blockH = title.size().height + 10 + subtitle.size().height + 34
    + gamesLine * CGFloat(games.count) + 34 + pillH
let x: CGFloat = 514
var y = (CGFloat(H) - blockH) / 2

title.draw(at: NSPoint(x: x, y: y));        y += title.size().height + 10
subtitle.draw(at: NSPoint(x: x, y: y));     y += subtitle.size().height + 34
for line in games {
    line.draw(at: NSPoint(x: x, y: y + (gamesLine - line.size().height) / 2))
    y += gamesLine
}
y += 34

// Pastille en dégradé braise.
let pillRect = NSRect(x: x, y: y, width: pillLabel.size().width + 52, height: pillH)
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2).addClip()
linear(cg, [hex("FFD000"), hex("FF5A1F")], [0, 1],
       from: CGPoint(x: pillRect.minX, y: pillRect.minY), to: CGPoint(x: pillRect.maxX, y: pillRect.maxY))
NSGraphicsContext.restoreGraphicsState()
pillLabel.draw(at: NSPoint(x: pillRect.minX + 26, y: pillRect.minY + 12))

NSGraphicsContext.current = nil
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Encodage PNG impossible")
}
try png.write(to: outURL)
print("Image écrite : \(outURL.path) (\(W)×\(H), police \(NSFont.systemFont(ofSize: 12).familyName ?? "?"))")
