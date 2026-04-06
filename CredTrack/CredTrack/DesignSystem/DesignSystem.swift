import SwiftUI

// MARK: - Colors

extension Color {
    // App semantic tokens — all mapped to NeoPop palette
    static let ctBackground    = Color.NeoPop.Black.c500      // #0D0D0D  Pop Black 500
    static let ctSurface       = Color.NeoPop.Black.c300      // #161616  Pop Black 300
    static let ctGold          = Color.NeoPop.White.c500      // #FFFFFF  Pop White
    static let ctGoldLight     = Color.NeoPop.White.c300      // #EFEFEF  Pop White 300
    static let ctTextPrimary   = Color.NeoPop.White.c500      // #FFFFFF  Pop White 500
    static let ctTextSecondary = Color.NeoPop.Black.c100      // #8A8A8A  Pop Black 100

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

// MARK: - NeoPop Color Palette
// Full palette from playground.cred.club — import via Color.NeoPop or UIColor.NeoPop
// Usage: Color.NeoPop.State.error500  |  Color.NeoPop.Manna.c500

extension Color {
    enum NeoPop {

        // ── State Colors ─────────────────────────────────────────────────────────
        enum State {
            // Error
            static let error100 = Color(hex: "FCE2DD")
            static let error200 = Color(hex: "F6A69B")
            static let error300 = Color(hex: "F47564")
            static let error400 = Color(hex: "F05E4B")
            static let error500 = Color(hex: "EE4D37")
            // Warning
            static let warning100 = Color(hex: "FBDDC2")
            static let warning200 = Color(hex: "F8C699")
            static let warning300 = Color(hex: "F5AC6A")
            static let warning400 = Color(hex: "F29947")
            static let warning500 = Color(hex: "F08D32")
            // Info
            static let info100 = Color(hex: "C2D0F2")
            static let info200 = Color(hex: "89A5E3")
            static let info300 = Color(hex: "3F6FD9")
            static let info400 = Color(hex: "2C5ECD")
            static let info500 = Color(hex: "144CC7")
            // Success
            static let success100 = Color(hex: "E6F9F1")
            static let success200 = Color(hex: "83E0B8")
            static let success300 = Color(hex: "4FE3A3")
            static let success400 = Color(hex: "1FC87F")
            static let success500 = Color(hex: "06C270")
        }

        // ── Pop Black ─────────────────────────────────────────────────────────────
        enum Black {
            static let c100 = Color(hex: "8A8A8A")
            static let c200 = Color(hex: "3D3D3D")
            static let c300 = Color(hex: "161616")
            static let c400 = Color(hex: "121212")
            static let c500 = Color(hex: "0D0D0D")
        }

        // ── Pop White ─────────────────────────────────────────────────────────────
        enum White {
            static let c100 = Color(hex: "D2D2D2")
            static let c200 = Color(hex: "E0E0E0")
            static let c300 = Color(hex: "EFEFEF")
            static let c400 = Color(hex: "FBFBFB")
            static let c500 = Color(hex: "FFFFFF")
        }

        // ── Poli Purple ───────────────────────────────────────────────────────────
        enum PoliPurple {
            static let c100 = Color(hex: "E8DFFF")
            static let c200 = Color(hex: "D2C2FF")
            static let c300 = Color(hex: "B49AFF")
            static let c400 = Color(hex: "9772FF")
            static let c500 = Color(hex: "6A35FF")
            static let c600 = Color(hex: "4A25B3")
            static let c700 = Color(hex: "351A80")
            static let c800 = Color(hex: "20104D")
        }

        // ── Orange Sunshine ───────────────────────────────────────────────────────
        enum OrangeSunshine {
            static let c100 = Color(hex: "FFEFE6")
            static let c200 = Color(hex: "FFDBC7")
            static let c300 = Color(hex: "FFC3A2")
            static let c400 = Color(hex: "FFAB7C")
            static let c500 = Color(hex: "FF8744")
            static let c600 = Color(hex: "B35F30")
            static let c700 = Color(hex: "804322")
            static let c800 = Color(hex: "4D2914")
        }

        // ── Pink Pong ─────────────────────────────────────────────────────────────
        enum PinkPong {
            static let c100 = Color(hex: "FFE1E9")
            static let c200 = Color(hex: "FFC6D4")
            static let c300 = Color(hex: "FFA0B7")
            static let c400 = Color(hex: "FF7B9A")
            static let c500 = Color(hex: "FF426F")
            static let c600 = Color(hex: "B32E4E")
            static let c700 = Color(hex: "802138")
            static let c800 = Color(hex: "4D1421")
        }

        // ── Manna (Yellow) ────────────────────────────────────────────────────────
        enum Manna {
            static let c100 = Color(hex: "FFF8E5")
            static let c200 = Color(hex: "FFEFC7")
            static let c300 = Color(hex: "FFE5A2")
            static let c400 = Color(hex: "FFDB7D")
            static let c500 = Color(hex: "FFCB45")   // ← CRED CTA yellow
            static let c600 = Color(hex: "B38E30")
            static let c700 = Color(hex: "806623")
            static let c800 = Color(hex: "4D3D15")
        }

        // ── Neo Paccha (Lime) ─────────────────────────────────────────────────────
        enum NeoPaccha {
            static let c100 = Color(hex: "FBFFE6")
            static let c200 = Color(hex: "F7FFC6")
            static let c300 = Color(hex: "F2FF9F")
            static let c400 = Color(hex: "EDFE79")
            static let c500 = Color(hex: "E5FE40")
            static let c600 = Color(hex: "A0B22D")
            static let c700 = Color(hex: "727F20")
            static let c800 = Color(hex: "454C13")
        }

        // ── Yoyo (Purple) ─────────────────────────────────────────────────────────
        enum Yoyo {
            static let c100 = Color(hex: "F4E5FF")
            static let c200 = Color(hex: "E5C5FF")
            static let c300 = Color(hex: "D59FFF")
            static let c400 = Color(hex: "C379FF")
            static let c500 = Color(hex: "AA3FFF")
            static let c600 = Color(hex: "772CB3")
            static let c700 = Color(hex: "552080")
            static let c800 = Color(hex: "33134D")
        }

        // ── Park Green ────────────────────────────────────────────────────────────
        enum ParkGreen {
            static let c100 = Color(hex: "DDFFF1")
            static let c200 = Color(hex: "C4FFE6")
            static let c300 = Color(hex: "9DFFD6")
            static let c400 = Color(hex: "76FFC6")
            static let c500 = Color(hex: "3BFFAD")
            static let c600 = Color(hex: "29B379")
            static let c700 = Color(hex: "1E8057")
            static let c800 = Color(hex: "124D34")
        }
    }
}

// UIKit mirror — same palette accessible from UIKit contexts (card views, NeoPop components)
extension UIColor {
    enum NeoPop {
        // ── Pop Black ─────────────────────────────────────────────────────────────
        enum Black {
            static let c100 = UIColor(hex: "8A8A8A")!
            static let c200 = UIColor(hex: "3D3D3D")!
            static let c300 = UIColor(hex: "161616")!
            static let c400 = UIColor(hex: "121212")!
            static let c500 = UIColor(hex: "0D0D0D")!
        }
        // ── Pop White ─────────────────────────────────────────────────────────────
        enum White {
            static let c100 = UIColor(hex: "D2D2D2")!
            static let c200 = UIColor(hex: "E0E0E0")!
            static let c300 = UIColor(hex: "EFEFEF")!
            static let c400 = UIColor(hex: "FBFBFB")!
            static let c500 = UIColor(hex: "FFFFFF")!
        }
        enum State {
            static let error100   = UIColor(hex: "FCE2DD")!; static let error200   = UIColor(hex: "F6A69B")!
            static let error300   = UIColor(hex: "F47564")!; static let error400   = UIColor(hex: "F05E4B")!
            static let error500   = UIColor(hex: "EE4D37")!
            static let warning100 = UIColor(hex: "FBDDC2")!; static let warning200 = UIColor(hex: "F8C699")!
            static let warning300 = UIColor(hex: "F5AC6A")!; static let warning400 = UIColor(hex: "F29947")!
            static let warning500 = UIColor(hex: "F08D32")!
            static let info100    = UIColor(hex: "C2D0F2")!; static let info200    = UIColor(hex: "89A5E3")!
            static let info300    = UIColor(hex: "3F6FD9")!; static let info400    = UIColor(hex: "2C5ECD")!
            static let info500    = UIColor(hex: "144CC7")!
            static let success100 = UIColor(hex: "E6F9F1")!; static let success200 = UIColor(hex: "83E0B8")!
            static let success300 = UIColor(hex: "4FE3A3")!; static let success400 = UIColor(hex: "1FC87F")!
            static let success500 = UIColor(hex: "06C270")!
        }
        enum Manna {
            static let c100 = UIColor(hex: "FFF8E5")!; static let c200 = UIColor(hex: "FFEFC7")!
            static let c300 = UIColor(hex: "FFE5A2")!; static let c400 = UIColor(hex: "FFDB7D")!
            static let c500 = UIColor(hex: "FFCB45")!  // CRED CTA yellow
            static let c600 = UIColor(hex: "B38E30")!; static let c700 = UIColor(hex: "806623")!
            static let c800 = UIColor(hex: "4D3D15")!
        }
        enum PoliPurple {
            static let c100 = UIColor(hex: "E8DFFF")!; static let c200 = UIColor(hex: "D2C2FF")!
            static let c300 = UIColor(hex: "B49AFF")!; static let c400 = UIColor(hex: "9772FF")!
            static let c500 = UIColor(hex: "6A35FF")!; static let c600 = UIColor(hex: "4A25B3")!
            static let c700 = UIColor(hex: "351A80")!; static let c800 = UIColor(hex: "20104D")!
        }
        enum OrangeSunshine {
            static let c100 = UIColor(hex: "FFEFE6")!; static let c200 = UIColor(hex: "FFDBC7")!
            static let c300 = UIColor(hex: "FFC3A2")!; static let c400 = UIColor(hex: "FFAB7C")!
            static let c500 = UIColor(hex: "FF8744")!; static let c600 = UIColor(hex: "B35F30")!
            static let c700 = UIColor(hex: "804322")!; static let c800 = UIColor(hex: "4D2914")!
        }
        enum PinkPong {
            static let c100 = UIColor(hex: "FFE1E9")!; static let c200 = UIColor(hex: "FFC6D4")!
            static let c300 = UIColor(hex: "FFA0B7")!; static let c400 = UIColor(hex: "FF7B9A")!
            static let c500 = UIColor(hex: "FF426F")!; static let c600 = UIColor(hex: "B32E4E")!
            static let c700 = UIColor(hex: "802138")!; static let c800 = UIColor(hex: "4D1421")!
        }
        enum NeoPaccha {
            static let c100 = UIColor(hex: "FBFFE6")!; static let c200 = UIColor(hex: "F7FFC6")!
            static let c300 = UIColor(hex: "F2FF9F")!; static let c400 = UIColor(hex: "EDFE79")!
            static let c500 = UIColor(hex: "E5FE40")!; static let c600 = UIColor(hex: "A0B22D")!
            static let c700 = UIColor(hex: "727F20")!; static let c800 = UIColor(hex: "454C13")!
        }
        enum Yoyo {
            static let c100 = UIColor(hex: "F4E5FF")!; static let c200 = UIColor(hex: "E5C5FF")!
            static let c300 = UIColor(hex: "D59FFF")!; static let c400 = UIColor(hex: "C379FF")!
            static let c500 = UIColor(hex: "AA3FFF")!; static let c600 = UIColor(hex: "772CB3")!
            static let c700 = UIColor(hex: "552080")!; static let c800 = UIColor(hex: "33134D")!
        }
        enum ParkGreen {
            static let c100 = UIColor(hex: "DDFFF1")!; static let c200 = UIColor(hex: "C4FFE6")!
            static let c300 = UIColor(hex: "9DFFD6")!; static let c400 = UIColor(hex: "76FFC6")!
            static let c500 = UIColor(hex: "3BFFAD")!; static let c600 = UIColor(hex: "29B379")!
            static let c700 = UIColor(hex: "1E8057")!; static let c800 = UIColor(hex: "124D34")!
        }
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
