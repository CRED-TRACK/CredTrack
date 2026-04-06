import SwiftUI

// MARK: - Colors

extension Color {
    static let ctBackground    = Color(hex: "000000")
    static let ctSurface       = Color(hex: "1A1A1A")
    static let ctGold          = Color(hex: "C9A84C")
    static let ctGoldLight     = Color(hex: "E8C86A")
    static let ctTextPrimary   = Color(hex: "FFFFFF")
    static let ctTextSecondary = Color(hex: "8A8A8A")

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Gradients

extension AngularGradient {
    static let ctWaveChromatic = AngularGradient(
        colors: [
            Color(red: 1.0, green: 0.82, blue: 0.82),
            Color(red: 0.95, green: 1.0, blue: 0.95),
            Color(red: 0.82, green: 0.90, blue: 1.0),
            Color(red: 1.0, green: 0.95, blue: 1.0),
            Color(red: 1.0, green: 0.82, blue: 0.82),
        ],
        center: .center
    )
}

// MARK: - Typography
//
// Mirrors CRED's type system from playground.cred.club
//
// Fonts (PostScript names):
//   Sans — Gilroy:    Gilroy-Regular, Gilroy-Medium, Gilroy-SemiBold, Gilroy-Bold, Gilroy-Extrabold
//   Serif — PPCirka:  PPCirka-Regular, PPCirka-Medium, PPCirka-Bold
//
// Scale buckets used in CredTrack:
//   ctWordmark    — 34 / Gilroy ExtraBold  (app logo / splash)
//   ctDisplay     — 28 / Gilroy ExtraBold  (screen titles)
//   ctHeadline    — 22 / Gilroy Bold       (section headers)
//   ctTitle       — 18 / Gilroy Bold       (card/item titles)
//   ctButtonLabel — 16 / Gilroy SemiBold   (CTA labels)
//   ctBody        — 15 / Gilroy Regular    (paragraph body)
//   ctBodyMedium  — 14 / Gilroy Medium     (secondary body)
//   ctCaption     — 12 / Gilroy SemiBold   (labels, tags)
//   ctMicro       — 10 / Gilroy Bold       (caps, badges)
//   ctSerif       — 32 / PPCirka Bold      (editorial / hero pull-quote)
//   ctSerifTitle  — 22 / PPCirka Bold      (serif section header)

extension Font {

    // ── Wordmark / Display ────────────────────────────────────────────────────
    static let ctWordmark    = gilroy(size: 34, weight: .extraBold)
    static let ctDisplay     = gilroy(size: 28, weight: .extraBold)

    // ── Headings (Gilroy sans) ────────────────────────────────────────────────
    static let ctHeadline    = gilroy(size: 22, weight: .bold)
    static let ctTitle       = gilroy(size: 18, weight: .bold)

    // ── UI Labels ─────────────────────────────────────────────────────────────
    static let ctButtonLabel = gilroy(size: 16, weight: .semiBold)
    static let ctTagline     = gilroy(size: 16, weight: .regular)

    // ── Body ──────────────────────────────────────────────────────────────────
    static let ctBody        = gilroy(size: 15, weight: .regular)
    static let ctBodyMedium  = gilroy(size: 14, weight: .medium)

    // ── Supporting ────────────────────────────────────────────────────────────
    static let ctCaption     = gilroy(size: 12, weight: .semiBold)
    static let ctMicro       = gilroy(size: 10, weight: .bold)

    // ── Serif (PPCirka) ───────────────────────────────────────────────────────
    static let ctSerif       = cirka(size: 32, weight: .bold)
    static let ctSerifTitle  = cirka(size: 22, weight: .bold)

    // MARK: - Gilroy factory

    enum GilroyWeight {
        case regular, medium, semiBold, bold, extraBold
        var postScriptName: String {
            switch self {
            case .regular:   return "Gilroy-Regular"
            case .medium:    return "Gilroy-Medium"
            case .semiBold:  return "Gilroy-SemiBold"
            case .bold:      return "Gilroy-Bold"
            case .extraBold: return "Gilroy-Extrabold"
            }
        }
        // System-font fallback weight used if the custom font fails to load
        var fallback: Font.Weight {
            switch self {
            case .regular:   return .regular
            case .medium:    return .medium
            case .semiBold:  return .semibold
            case .bold:      return .bold
            case .extraBold: return .black
            }
        }
    }

    static func gilroy(size: CGFloat, weight: GilroyWeight) -> Font {
        let name = weight.postScriptName
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        // Graceful fallback — keeps layout intact if font not registered yet
        return .system(size: size, weight: weight.fallback, design: .default)
    }

    // MARK: - PPCirka factory

    enum CirkaWeight {
        case regular, medium, bold
        var postScriptName: String {
            switch self {
            case .regular: return "PPCirka-Regular"
            case .medium:  return "PPCirka-Medium"
            case .bold:    return "PPCirka-Bold"
            }
        }
        var fallback: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium:  return .medium
            case .bold:    return .bold
            }
        }
    }

    static func cirka(size: CGFloat, weight: CirkaWeight) -> Font {
        let name = weight.postScriptName
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight.fallback, design: .serif)
    }
}

// MARK: - UIFont convenience (for UIKit labels on cards, buttons, etc.)

extension UIFont {
    static func gilroy(_ weight: Font.GilroyWeight, size: CGFloat) -> UIFont {
        UIFont(name: weight.postScriptName, size: size)
            ?? .systemFont(ofSize: size, weight: weight.uiKitWeight)
    }

    static func cirka(_ weight: Font.CirkaWeight, size: CGFloat) -> UIFont {
        if let font = UIFont(name: weight.postScriptName, size: size) { return font }
        // Serif system fallback (iOS 13+)
        if let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return .systemFont(ofSize: size)
    }
}

private extension Font.GilroyWeight {
    var uiKitWeight: UIFont.Weight {
        switch self {
        case .regular:   return .regular
        case .medium:    return .medium
        case .semiBold:  return .semibold
        case .bold:      return .bold
        case .extraBold: return .black
        }
    }
}
