import SwiftUI
import Synth

// MARK: - Model

enum CardNetwork {
    case visa, mastercard, amex, discover
}

struct DemoCard: Identifiable {
    let id:          UUID = UUID()
    let cardName:    String
    let bank:        String
    let lastFour:    String
    let network:     CardNetwork
    let faceColor:   UIColor
    let gradientEnd: UIColor
    let textColor:   UIColor

    static let allDemoCards: [DemoCard] = [
        DemoCard(
            cardName:    "Sapphire Reserve",
            bank:        "Chase",
            lastFour:    "4821",
            network:     .visa,
            faceColor:   UIColor(red: 0.10, green: 0.20, blue: 0.42, alpha: 1),
            gradientEnd: UIColor(red: 0.06, green: 0.12, blue: 0.26, alpha: 1),
            textColor:   .white
        ),
    ]
}

// MARK: - Dimensions

let cardWidth:  CGFloat = 340
let cardHeight: CGFloat = 214

// MARK: - UIKit Card View
// Inherits the neumorphic elevated surface from NeuCardSurface (NeuCard.swift).
// CreditCardUIView only adds card-specific content: chip, network logo, labels.

final class CreditCardUIView: NeuCardSurface {

    private let chipView     = UIView()
    private let networkView  = NetworkLogoView()
    private let bankLabel    = UILabel()
    private let nameLabel    = UILabel()
    private let numberLabel  = UILabel()
    private let holderLabel  = UILabel()
    private let expLabel     = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func buildLayout() {
        // Chip
        chipView.frame              = CGRect(x: 26, y: 78, width: 42, height: 33)
        chipView.layer.cornerRadius = 6
        addSubview(chipView)

        let hLine = UIView(frame: CGRect(x: 0,  y: 16, width: 42, height: 1))
        let vLine = UIView(frame: CGRect(x: 21, y: 0,  width: 1,  height: 33))
        hLine.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        vLine.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        chipView.addSubview(hLine)
        chipView.addSubview(vLine)

        // Network — top right
        networkView.frame = CGRect(x: cardWidth - 76, y: 20, width: 56, height: 28)
        addSubview(networkView)

        // Bank — top left
        bankLabel.frame = CGRect(x: 26, y: 22, width: 200, height: 16)
        bankLabel.font  = .systemFont(ofSize: 11, weight: .medium)
        bankLabel.alpha = 0.65
        addSubview(bankLabel)

        // Card name
        nameLabel.frame = CGRect(x: 26, y: 40, width: 220, height: 22)
        nameLabel.font  = .systemFont(ofSize: 15, weight: .semibold)
        addSubview(nameLabel)

        // Number
        numberLabel.frame = CGRect(x: 26, y: cardHeight - 66, width: cardWidth - 52, height: 26)
        numberLabel.font  = .monospacedSystemFont(ofSize: 17, weight: .light)
        addSubview(numberLabel)

        // Holder
        holderLabel.frame = CGRect(x: 26, y: cardHeight - 34, width: 180, height: 18)
        holderLabel.font  = .systemFont(ofSize: 11, weight: .medium)
        holderLabel.alpha = 0.75
        addSubview(holderLabel)

        // Expiry — bottom right
        expLabel.frame         = CGRect(x: cardWidth - 100, y: cardHeight - 34, width: 74, height: 18)
        expLabel.font          = .systemFont(ofSize: 11, weight: .regular)
        expLabel.textAlignment = .right
        expLabel.alpha         = 0.65
        addSubview(expLabel)
    }

    // MARK: - Configure
    func configure(with card: DemoCard) {
        // Apply the Synth elevated-soft surface (gradient, border, shadows)
        applyElevatedSoftStyle(baseColor: card.faceColor, gradientEnd: card.gradientEnd)

        // ── Chip ──────────────────────────────────────────────────────────
        let tc = card.textColor
        chipView.backgroundColor   = UIColor(red: 0.82, green: 0.70, blue: 0.34, alpha: 0.9)
        chipView.layer.borderWidth = 0.5
        chipView.layer.borderColor = UIColor.black.withAlphaComponent(0.20).cgColor

        networkView.configure(network: card.network, tint: tc)

        bankLabel.text      = card.bank.uppercased()
        bankLabel.textColor = tc

        nameLabel.text      = card.cardName
        nameLabel.textColor = tc

        numberLabel.attributedText = NSAttributedString(
            string: "••••  ••••  ••••  \(card.lastFour)",
            attributes: [.kern: 1.6, .foregroundColor: tc]
        )

        holderLabel.text      = "JOHN DOE"
        holderLabel.textColor = tc

        expLabel.text      = "12 / 28"
        expLabel.textColor = tc
    }
}

// MARK: - Network Logo

private final class NetworkLogoView: UIView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.frame            = bounds
        label.textAlignment    = .right
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(network: CardNetwork, tint: UIColor) {
        switch network {
        case .visa:
            label.text      = "VISA"
            let base        = UIFont.systemFont(ofSize: 20, weight: .black).fontDescriptor
            label.font      = UIFont(descriptor: base.withSymbolicTraits(.traitItalic) ?? base, size: 20)
            label.textColor = tint
        case .mastercard:
            label.text      = "mc"
            label.font      = .systemFont(ofSize: 22, weight: .black)
            label.textColor = tint
        case .amex:
            label.text      = "AMEX"
            label.font      = .systemFont(ofSize: 13, weight: .bold)
            label.textColor = tint.withAlphaComponent(0.85)
        case .discover:
            label.text      = "DISCOVER"
            label.font      = .systemFont(ofSize: 10, weight: .semibold)
            label.textColor = tint.withAlphaComponent(0.85)
        }
    }
}

// MARK: - SwiftUI Wrapper

struct CreditCardView: UIViewRepresentable {
    let card:      DemoCard
    var isPressed: Bool = false

    func makeUIView(context: Context) -> CreditCardUIView {
        let v = CreditCardUIView(frame: CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight))
        v.configure(with: card)
        return v
    }

    func updateUIView(_ uiView: CreditCardUIView, context: Context) {
        // SwiftUI tells UIKit when the card is pressed → gradient swaps
        uiView.setPressed(isPressed)
    }
}
