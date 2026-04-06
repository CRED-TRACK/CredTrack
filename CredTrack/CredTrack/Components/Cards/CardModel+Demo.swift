import UIKit

// MARK: - Demo cards (static placeholder until API is wired up)
// When real data arrives, replace `allDemoCards` with API-mapped CardModels.
// The UI reads only CardModel fields — no design changes needed.

extension CardModel {
    static let allDemoCards: [CardModel] = [
        CardModel(
            cardName: "Sapphire Reserve", bank: "Chase",
            lastFour: "4821", network: .visa, issuerAsset: "chase",
            faceColor:   UIColor(red: 0.10, green: 0.20, blue: 0.42, alpha: 1),
            gradientEnd: UIColor(red: 0.06, green: 0.12, blue: 0.26, alpha: 1)
        ),
        CardModel(
            cardName: "World Elite", bank: "Citi",
            lastFour: "3902", network: .mastercard, issuerAsset: "citi",
            faceColor:   UIColor(red: 0.14, green: 0.14, blue: 0.18, alpha: 1),
            gradientEnd: UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1)
        ),
        CardModel(
            cardName: "Platinum", bank: "American Express",
            lastFour: "1005", network: .amex, issuerAsset: "amex",
            faceColor:   UIColor(red: 0.10, green: 0.22, blue: 0.18, alpha: 1),
            gradientEnd: UIColor(red: 0.06, green: 0.13, blue: 0.10, alpha: 1)
        ),
        CardModel(
            cardName: "it Cash Back", bank: "Discover",
            lastFour: "7741", network: .discover, issuerAsset: "discover 1",
            faceColor:   UIColor(red: 0.32, green: 0.08, blue: 0.08, alpha: 1),
            gradientEnd: UIColor(red: 0.20, green: 0.04, blue: 0.04, alpha: 1)
        ),
        CardModel(
            cardName: "Customized Cash", bank: "Bank of America",
            lastFour: "6103", network: .visa, issuerAsset: "bofa",
            faceColor:   UIColor(red: 0.20, green: 0.05, blue: 0.08, alpha: 1),
            gradientEnd: UIColor(red: 0.12, green: 0.02, blue: 0.04, alpha: 1)
        ),
        CardModel(
            cardName: "Venture X", bank: "Capital One",
            lastFour: "8847", network: .mastercard, issuerAsset: "capitalone",
            faceColor:   UIColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 1),
            gradientEnd: UIColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1)
        ),
        CardModel(
            cardName: "Cash+ Visa", bank: "U.S. Bank",
            lastFour: "2290", network: .visa, issuerAsset: "usbank",
            faceColor:   UIColor(red: 0.16, green: 0.08, blue: 0.28, alpha: 1),
            gradientEnd: UIColor(red: 0.10, green: 0.04, blue: 0.18, alpha: 1)
        ),
        CardModel(
            cardName: "Active Cash", bank: "Wells Fargo",
            lastFour: "5519", network: .visa, issuerAsset: "wellsfargo",
            faceColor:   UIColor(red: 0.26, green: 0.16, blue: 0.04, alpha: 1),
            gradientEnd: UIColor(red: 0.16, green: 0.10, blue: 0.02, alpha: 1)
        ),
    ]
}
