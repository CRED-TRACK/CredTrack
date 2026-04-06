import UIKit

// MARK: - CardNetwork

enum CardNetwork: String {
    case visa        = "VISA"
    case mastercard  = "MASTERCARD"
    case amex        = "AMERICAN EXPRESS"
    case discover    = "DISCOVER"
    case unknown

    // Maps raw API brand string → enum
    // e.g. "VISA", "Visa", "visa" all resolve correctly
    static func from(_ brand: String) -> CardNetwork {
        let upper = brand.uppercased()
        if upper.contains("VISA")              { return .visa }
        if upper.contains("MASTERCARD")        { return .mastercard }
        if upper.contains("AMERICAN EXPRESS")  { return .amex }
        if upper.contains("DISCOVER")          { return .discover }
        return .unknown
    }

    // Asset name in Assets.xcassets
    var assetName: String {
        switch self {
        case .visa:       return "VISA"
        case .mastercard: return "MASTERCARD"
        case .amex:       return "AMERICAN EXPRESS"
        case .discover:   return "DISCOVER"
        case .unknown:    return ""
        }
    }
}

// MARK: - IssuerResolver
// Maps raw issuer names from bin_records CSV/API → local asset names.
// Uses contains-matching so "JPMORGAN CHASE BANK, N.A." → "chase".

enum IssuerResolver {
    static func assetName(for issuerName: String) -> String? {
        let u = issuerName.uppercased()
        if u.contains("JPMORGAN CHASE") || u.contains("CHASE BANK")   { return "chase" }
        if u.contains("AMERICAN EXPRESS")                              { return "amex" }
        if u.contains("BANK OF AMERICA")                               { return "bofa" }
        if u.contains("WELLS FARGO")                                   { return "wellsfargo" }
        if u.contains("U.S. BANK") || u.contains("US BANK")           { return "usbank" }
        if u.contains("CAPITAL ONE")                                   { return "capitalone" }
        if u.contains("CITIBANK") || u.contains("CITI ")              { return "citi" }
        if u.contains("DISCOVER")                                      { return "discover 1" }
        return nil   // no local asset → IssuerLogoView shows text fallback
    }
}

// MARK: - CardModel

struct CardModel: Identifiable {
    let id:          UUID   = UUID()
    let cardName:    String           // product variant, e.g. "Sapphire Reserve"
    let bank:        String           // display issuer name, e.g. "Chase"
    let lastFour:    String
    let network:     CardNetwork
    let issuerAsset: String?          // resolved asset name, nil = text fallback
    let faceColor:   UIColor
    let gradientEnd: UIColor
    let textColor:   UIColor

    // MARK: Init from raw API / BIN data
    init(
        cardName:    String,
        bank:        String,
        lastFour:    String,
        brandString: String,          // raw brand from API e.g. "VISA"
        issuerName:  String,          // raw issuer from API e.g. "JPMORGAN CHASE BANK, N.A."
        faceColor:   UIColor,
        gradientEnd: UIColor,
        textColor:   UIColor = .white
    ) {
        self.cardName    = cardName
        self.bank        = bank
        self.lastFour    = lastFour
        self.network     = CardNetwork.from(brandString)
        self.issuerAsset = IssuerResolver.assetName(for: issuerName)
        self.faceColor   = faceColor
        self.gradientEnd = gradientEnd
        self.textColor   = textColor
    }

    // MARK: Convenience init (when you already have resolved values — used by demo data)
    init(
        cardName:    String,
        bank:        String,
        lastFour:    String,
        network:     CardNetwork,
        issuerAsset: String?,
        faceColor:   UIColor,
        gradientEnd: UIColor,
        textColor:   UIColor = .white
    ) {
        self.cardName    = cardName
        self.bank        = bank
        self.lastFour    = lastFour
        self.network     = network
        self.issuerAsset = issuerAsset
        self.faceColor   = faceColor
        self.gradientEnd = gradientEnd
        self.textColor   = textColor
    }
}

// MARK: - UIColor helpers

extension UIColor {
    // Parse hex string from API e.g. "#1A3370" or "1A3370"
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >>  8) & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }

    // Darker shade of a colour — useful for gradientEnd when API only provides one colour
    func darkened(by fraction: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - r*fraction, 0),
                       green: max(g - g*fraction, 0),
                       blue:  max(b - b*fraction, 0),
                       alpha: a)
    }

    func lightened(by fraction: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r + (1-r)*fraction, 1),
                       green: min(g + (1-g)*fraction, 1),
                       blue:  min(b + (1-b)*fraction, 1),
                       alpha: a)
    }
}
