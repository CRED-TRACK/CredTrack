import SwiftUI

// MARK: - Dimensions

let cardWidth:  CGFloat = 340
let cardHeight: CGFloat = 214

// MARK: - CreditCardUIView
// Renders a CardModel onto a NeuCardSurface.
// All design decisions (layout, fonts, sizes) live here.
// All data decisions (colours, issuer, network) live in CardModel.

final class CreditCardUIView: NeuCardSurface {

    private let chipView    = UIView()
    private let issuerView  = IssuerLogoView()
    private let networkView = NetworkLogoView()
    private let nameLabel   = UILabel()
    private let numberLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout (structure only — no data)

    private func buildLayout() {
        // Issuer logo — full card canvas, image centred inside
        issuerView.frame = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        addSubview(issuerView)

        // Chip
        chipView.frame              = CGRect(x: 16, y: 74, width: 42, height: 33)
        chipView.layer.cornerRadius = 6
        addSubview(chipView)

        let hLine = UIView(frame: CGRect(x: 0,  y: 16, width: 42, height: 1))
        let vLine = UIView(frame: CGRect(x: 21, y: 0,  width: 1,  height: 33))
        hLine.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        vLine.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        chipView.addSubview(hLine)
        chipView.addSubview(vLine)

        // Network logo — top right
        networkView.frame = CGRect(x: cardWidth - 100, y: 14, width: 74, height: 36)
        addSubview(networkView)

        // Variant name — top left
        nameLabel.frame = CGRect(x: 22, y: 16, width: 180, height: 18)
        nameLabel.font  = .gilroy(.semiBold, size: 12)
        nameLabel.alpha = 0.90
        addSubview(nameLabel)

        // Card number — monospaced so digits stay vertically aligned
        numberLabel.frame = CGRect(x: 26, y: cardHeight - 62, width: cardWidth - 52, height: 24)
        numberLabel.font  = .monospacedSystemFont(ofSize: 16, weight: .light)
        addSubview(numberLabel)
    }

    // MARK: - Configure (data → view, no layout logic)

    func configure(with card: CardModel) {
        applyElevatedSoftStyle(baseColor: card.faceColor, gradientEnd: card.gradientEnd)

        let tc = card.textColor

        chipView.backgroundColor   = UIColor(red: 0.82, green: 0.70, blue: 0.34, alpha: 0.9)
        chipView.layer.borderWidth = 0.5
        chipView.layer.borderColor = UIColor.black.withAlphaComponent(0.20).cgColor

        issuerView.configure(assetName: card.issuerAsset,
                             fallbackText: card.bank,
                             fallbackType: card.network.assetName,
                             tint: tc)

        networkView.isHidden = card.network == .amex
        if card.network != .amex {
            networkView.configure(network: card.network)
        }

        nameLabel.text      = card.cardName
        nameLabel.textColor = tc

        numberLabel.attributedText = NSAttributedString(
            string: "••••  ••••  ••••  \(card.lastFour)",
            attributes: [.kern: 1.6, .foregroundColor: tc]
        )
    }
}

// MARK: - IssuerLogoView

private final class IssuerLogoView: UIView {

    private let imageView  = UIImageView()
    private let nameLabel  = UILabel()
    private let typeLabel  = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode   = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)

        nameLabel.font          = .gilroy(.semiBold, size: 12)
        nameLabel.numberOfLines = 2
        addSubview(nameLabel)

        typeLabel.font  = .gilroy(.regular, size: 10)
        typeLabel.alpha = 0.65
        addSubview(typeLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(assetName: String?, fallbackText: String, fallbackType: String, tint: UIColor) {
        if let name = assetName, let img = UIImage(named: name) {
            let maxH   = bounds.height * 0.38
            let maxW   = bounds.width  * 0.55
            let scale  = min(maxH / img.size.height, maxW / img.size.width)
            let w = img.size.width  * scale
            let h = img.size.height * scale
            imageView.frame    = CGRect(x: (bounds.width  - w) / 2,
                                        y: (bounds.height - h) / 2,
                                        width: w, height: h)
            imageView.image    = img
            imageView.isHidden = false
            nameLabel.isHidden = true
            typeLabel.isHidden = true
        } else {
            // Top-left: bank name, then type below it
            nameLabel.frame     = CGRect(x: 22, y: 42, width: 200, height: 32)
            nameLabel.text      = fallbackText.uppercased()
            nameLabel.textColor = tint

            typeLabel.frame     = CGRect(x: 22, y: 76, width: 200, height: 14)
            typeLabel.text      = fallbackType
            typeLabel.textColor = tint

            nameLabel.isHidden  = false
            typeLabel.isHidden  = fallbackType.isEmpty
            imageView.isHidden  = true
        }
    }
}

// MARK: - NetworkLogoView

private final class NetworkLogoView: UIView {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.frame            = bounds
        imageView.contentMode      = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(network: CardNetwork) {
        imageView.image = UIImage(named: network.assetName)
    }
}

// MARK: - SwiftUI Wrapper

struct CreditCardView: UIViewRepresentable {
    let card:      CardModel
    var isPressed: Bool = false

    func makeUIView(context: Context) -> CreditCardUIView {
        let v = CreditCardUIView(frame: CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight))
        v.configure(with: card)
        return v
    }

    func updateUIView(_ uiView: CreditCardUIView, context: Context) {
        uiView.configure(with: card)
        uiView.setPressed(isPressed)
    }
}
