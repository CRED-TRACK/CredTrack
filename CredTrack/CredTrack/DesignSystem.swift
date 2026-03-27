import SwiftUI

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

extension Font {
    static let ctWordmark    = Font.system(size: 34, weight: .black,    design: .default)
    static let ctDisplay     = Font.system(size: 28, weight: .bold,     design: .default)
    static let ctHeadline    = Font.system(size: 22, weight: .semibold, design: .default)
    static let ctTagline     = Font.system(size: 16, weight: .regular,  design: .default)
    static let ctButtonLabel = Font.system(size: 16, weight: .semibold, design: .default)
    static let ctCaption     = Font.system(size: 12, weight: .regular,  design: .default)
}
