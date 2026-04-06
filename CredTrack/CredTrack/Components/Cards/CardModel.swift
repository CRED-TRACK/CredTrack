import UIKit

// MARK: - CardNetwork

enum CardNetwork: String {
    case visa        = "VISA"
    case mastercard  = "MASTERCARD"
    case amex        = "AMERICAN EXPRESS"
    case discover    = "DISCOVER"
    case unknown

    static func from(_ brand: String) -> CardNetwork {
        let upper = brand.uppercased()
        if upper.contains("VISA")             { return .visa }
        if upper.contains("MASTERCARD")       { return .mastercard }
        if upper.contains("AMERICAN EXPRESS") { return .amex }
        if upper.contains("DISCOVER")         { return .discover }
        return .unknown
    }

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

// MARK: - BankKey → logo asset
// Maps the stable bank_key from the API to a local asset name in Assets.xcassets.
// Add an entry here whenever a new logo asset is added.

private let bankKeyAssets: [String: String] = [
    "CHASE":        "chase",
    "AMEX":         "amex",
    "CITI":         "citi",
    "CAPITAL_ONE":  "capitalone",
    "BOA":          "bofa",
    "WELLS_FARGO":  "wellsfargo",
    "DISCOVER":     "discover 1",
    "US_BANK":      "usbank",
]

// MARK: - CardModel

struct CardModel: Identifiable {
    let id:          UUID   = UUID()
    let cardName:    String
    let bank:        String
    let lastFour:    String
    let network:     CardNetwork
    let bankKey:     String?          // e.g. "CHASE" — drives logo selection
    let issuerAsset: String?          // resolved asset name, nil = text fallback
    let faceColor:   UIColor
    let gradientEnd: UIColor
    let textColor:   UIColor

    init(
        cardName:    String,
        bank:        String,
        lastFour:    String,
        brandString: String,
        bankKey:     String?,
        faceColor:   UIColor,
        gradientEnd: UIColor,
        textColor:   UIColor = .white
    ) {
        self.cardName    = cardName
        self.bank        = bank
        self.lastFour    = lastFour
        self.network     = CardNetwork.from(brandString)
        self.bankKey     = bankKey
        self.issuerAsset = bankKey.flatMap { bankKeyAssets[$0] }
        self.faceColor   = faceColor
        self.gradientEnd = gradientEnd
        self.textColor   = textColor
    }
}

// MARK: - UIColor helpers

extension UIColor {
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
