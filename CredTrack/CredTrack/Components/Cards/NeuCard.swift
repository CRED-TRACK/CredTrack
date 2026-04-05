import UIKit
import Synth

// MARK: - Reusable Synth elevated-soft card surface
// Provides the neumorphic elevated appearance (gradient face, Synth border rim,
// outer shadow layers) for any card-shaped content. Used by CreditCardUIView.

class NeuCardSurface: UIView {

    private let faceGradientLayer = CAGradientLayer()
    private(set) var idleColors:    [CGColor] = []
    private(set) var pressedColors: [CGColor] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = false
        clipsToBounds       = false
        faceGradientLayer.masksToBounds = true
        layer.insertSublayer(faceGradientLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        faceGradientLayer.frame        = bounds
        faceGradientLayer.cornerRadius = layer.cornerRadius
    }

    // Call once with card colours + corner radius to apply the full Synth surface
    func applyElevatedSoftStyle(
        baseColor:    UIColor,
        gradientEnd:  UIColor,
        cornerRadius: CGFloat = 20
    ) {
        layer.cornerRadius = cornerRadius

        idleColors    = [baseColor.cgColor, gradientEnd.cgColor]
        pressedColors = [gradientEnd.cgColor, baseColor.cgColor]

        faceGradientLayer.colors     = idleColors
        faceGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        faceGradientLayer.endPoint   = CGPoint(x: 1, y: 1)

        var neu = NeuConstants.NeuViewModel(baseColor: baseColor)
        neu.bgGradientColors    = nil
        neu.lightDirection      = .topLeft
        neu.shadowType          = .outer
        neu.hideBorder          = false
        neu.borderGradientWidth = 1.0
        neu.lightShadowModel = NeuConstants.NeuShadowModel(
            xOffset: -8, yOffset: -8, blur: 20, spread: -2,
            color: baseColor.lightened(by: 0.8), opacity: 0.15)
        neu.darkShadowModel  = NeuConstants.NeuShadowModel(
            xOffset:  8, yOffset:  8, blur: 18, spread: -1,
            color: baseColor.darkened(by: 0.8), opacity: 0.70)
        applyNeuStyle(model: neu)

        faceGradientLayer.removeFromSuperlayer()
        layer.insertSublayer(faceGradientLayer, at: 0)
    }

    // Drive gradient swap from press state (call from updateUIView)
    func setPressed(_ pressed: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(pressed ? 0.10 : 0.40)
        faceGradientLayer.colors = pressed ? pressedColors : idleColors
        CATransaction.commit()
    }
}

// MARK: - UIColor elevation helpers (mirrors Synth internal methods)

extension UIColor {
    func lightened(by fraction: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r+(1-r)*fraction,1), green: min(g+(1-g)*fraction,1), blue: min(b+(1-b)*fraction,1), alpha: a)
    }
    func darkened(by fraction: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r-r*fraction,0), green: max(g-g*fraction,0), blue: max(b-b*fraction,0), alpha: a)
    }
}
