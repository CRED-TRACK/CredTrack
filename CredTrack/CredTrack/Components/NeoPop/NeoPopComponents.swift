import UIKit
import SwiftUI
import NeoPop

// MARK: - NeoPop colour palette  (matches playground.cred.club)

extension UIColor {
    static let popBlack     = UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1) // #121212
    static let popDeepBlack = UIColor(red: 0.051, green: 0.051, blue: 0.051, alpha: 1) // #0D0D0D
    static let popBorder    = UIColor(red: 0.263, green: 0.263, blue: 0.263, alpha: 1) // #434343
}

// MARK: - Floating button
//
//  shimmer: false  →  Continue        (white face, black text/arrow)
//  shimmer: true   →  Add to Wallet   (CRED yellow face, black text, white shimmer)

// MARK: - PopButtonHost
// PopFloatingButton's reconfigurePopViews() uses bounds.height to calculate
// the 3D inclination angle and bails if bounds == .zero (which it always is
// during makeUIView). Deferring configureFloatingButton until the first
// layoutSubviews call with a real non-zero frame fixes the blank-button issue.

final class PopButtonHost: UIView {

    let button = PopFloatingButton()
    private var configured = false

    var onFirstLayout: ((PopFloatingButton) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        button.frame = bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(button)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty, !configured else { return }
        configured = true
        onFirstLayout?(button)
    }
}

// MARK: - NeoPopFloatingButton

struct NeoPopFloatingButton: UIViewRepresentable {
    let title:      String
    var isEnabled:  Bool    = true
    var shimmer:    Bool    = false
    var faceColor:  UIColor = .white
    var labelColor: UIColor = .black
    var showArrow:  Bool    = true
    let action:     () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> PopButtonHost {
        let host = PopButtonHost()

        host.button.delayTouchEvents = true
        host.button.addTarget(context.coordinator,
                              action: #selector(Coordinator.tapped),
                              for: .touchUpInside)

        // Configure once bounds are known (non-zero) so reconfigurePopViews()
        // can compute the correct 3D inclination angle.
        let shimmerFlag  = shimmer
        let titleStr     = title
        let enabled      = isEnabled
        let faceCol      = faceColor
        let labelCol     = labelColor
        let arrowFlag    = showArrow

        host.onFirstLayout = { btn in
            if shimmerFlag {
                // ── Add to Wallet — original library sample, verbatim ────────────
                btn.configureFloatingButton(withModel: PopFloatingButton.Model(
                    backgroundColor: UIColor.yellow,
                    edgeWidth: 9,
                    shimmerModel: PopShimmerModel(
                        spacing:    10,
                        lineColor1: UIColor.white,
                        lineColor2: UIColor.white,
                        lineWidth1: 16,
                        lineWidth2: 35,
                        duration:   1,
                        delay:      1.5
                    )
                ))
                btn.configureButtonContent(withModel: PopButtonContainerView.Model(
                    attributedTitle: NSAttributedString(
                        string: titleStr,
                        attributes: [
                            .foregroundColor: UIColor.black,
                            .font: UIFont.gilroy(.semiBold, size: 16)
                        ]
                    ),
                    leftImage:           nil,
                    leftImageTintColor:  nil,
                    rightImage:          nil,
                    rightImageTintColor: nil,
                    leftImageScale:      1.0,
                    rightImageScale:     1.0
                ))
                btn.startShimmerAnimation()
            } else {
                // ── Configurable face — Continue (white) or destructive (red) ────
                btn.configureFloatingButton(withModel: PopFloatingButton.Model(
                    backgroundColor: faceCol,
                    shadowColor:     .popDeepBlack,
                    edgeWidth:       9
                ))
                let displayTitle = arrowFlag ? titleStr + "  →" : titleStr
                btn.configureButtonContent(withModel: PopButtonContainerView.Model(
                    attributedTitle: NSAttributedString(
                        string: displayTitle,
                        attributes: [
                            .foregroundColor: labelCol,
                            .font: UIFont.gilroy(.semiBold, size: 16)
                        ]
                    ),
                    leftImage:           nil,
                    leftImageTintColor:  nil,
                    rightImage:          nil,
                    rightImageTintColor: nil,
                    leftImageScale:      1.0,
                    rightImageScale:     1.0
                ))
            }

            if !enabled { btn.disableButtonImmediately(withAlpha: true) }
        }

        return host
    }

    func updateUIView(_ host: PopButtonHost, context: Context) {
        guard host.button.isDescendant(of: host) else { return }
        isEnabled ? host.button.enableButton() : host.button.disableButtonImmediately(withAlpha: true)
    }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

// MARK: - NeoPopElevatedButton
// Wraps NeoPop's PopButton — the 3D bottomRight elevated style.
// Uses the same deferred-layout pattern as PopButtonHost so
// configurePopButton is never called with a zero frame.

final class PopElevatedButtonHost: UIView {
    let button = PopButton()
    private var configured = false
    var onFirstLayout: ((PopButton) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        button.frame = bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(button)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty, !configured else { return }
        configured = true
        onFirstLayout?(button)
    }
}

struct NeoPopElevatedButton: UIViewRepresentable {
    let title:          String
    var faceColor:      UIColor = .white
    var labelColor:     UIColor = .black
    var superViewColor: UIColor = .popDeepBlack
    var fontSize:       CGFloat = 16
    let action:         () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> PopElevatedButtonHost {
        let host = PopElevatedButtonHost()
        host.button.addTarget(context.coordinator,
                              action: #selector(Coordinator.tapped),
                              for: .touchUpInside)

        let faceCol      = faceColor
        let labelCol     = labelColor
        let superCol     = superViewColor
        let titleStr     = title
        let fontSz       = fontSize

        host.onFirstLayout = { btn in
            btn.configurePopButton(withModel: PopButton.Model(
                position:        .bottomRight,
                backgroundColor: faceCol,
                superViewColor:  superCol
            ))
            btn.configureButtonContent(withModel: PopButtonContainerView.Model(
                attributedTitle: NSAttributedString(
                    string: titleStr,
                    attributes: [
                        .foregroundColor: labelCol,
                        .font: UIFont.gilroy(.semiBold, size: fontSz)
                    ]
                ),
                leftImage:           nil,
                leftImageTintColor:  nil,
                rightImage:          nil,
                rightImageTintColor: nil,
                leftImageScale:      1.0,
                rightImageScale:     1.0
            ))
        }
        return host
    }

    func updateUIView(_ host: PopElevatedButtonHost, context: Context) {}

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

// MARK: - Input field  (NeoPop-bordered container wrapping UITextField)

struct NeoPopInputField: UIViewRepresentable {
    let placeholder:        String
    @Binding var text:      String
    var keyboardType:       UIKeyboardType                 = .default
    var autocapitalization: UITextAutocapitalizationType   = .sentences
    var font:               UIFont                         = .gilroy(.medium, size: 16)
    var prefix:             String?                        = nil
    var leadingImage:       UIImage?                       = nil
    var borderColor:        UIColor                        = .white
    var onCommit:           (() -> Void)?                  = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .popBlack
        container.clipsToBounds   = false

        // NeoPop border + 3-D edge (color driven by borderColor property)
        container.applyNeoPopStyle(model: PopView.Model(
            popEdgeDirection:    .bottomRight,
            backgroundColor:     .popBlack,
            verticalEdgeColor:   PopHelper.verticalEdgeColor(for: borderColor),
            horizontalEdgeColor: PopHelper.horizontalEdgeColor(for: borderColor)
        ))

        // Optional prefix label (e.g. "$")
        var leadingOffset: CGFloat = 20
        if let prefix {
            let lbl = UILabel()
            lbl.text      = prefix
            lbl.font      = .gilroy(.semiBold, size: 18)
            lbl.textColor = .white
            lbl.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
                lbl.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            leadingOffset = 20 + lbl.intrinsicContentSize.width + 6
        }

        let tf = UITextField()
        tf.placeholder            = placeholder
        tf.text                   = text
        tf.font                   = font
        tf.textColor              = .white
        tf.keyboardType           = keyboardType
        tf.autocapitalizationType = autocapitalization
        tf.autocorrectionType     = .no
        tf.tintColor              = .white
        tf.attributedPlaceholder  = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.popBorder]
        )
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.changed(_:)),
                     for: .editingChanged)

        // Trailing network logo — flush with the right edge of the text field
        let rightContainer = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 28))
        let iv = UIImageView(frame: CGRect(x: 4, y: 4, width: 40, height: 20))
        iv.contentMode = .scaleAspectFit
        iv.image = leadingImage
        rightContainer.addSubview(iv)
        tf.rightView = rightContainer
        tf.rightViewMode = leadingImage != nil ? .always : .never

        tf.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tf)
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leadingOffset),
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            tf.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            tf.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let tf = container.subviews.compactMap({ $0 as? UITextField }).first else { return }

        // Sync text field value
        if tf.text != text { tf.text = text }

        // Update trailing network logo with a crossfade
        if let iv = tf.rightView?.subviews.compactMap({ $0 as? UIImageView }).first {
            UIView.transition(with: iv, duration: 0.15, options: .transitionCrossDissolve, animations: {
                iv.image = self.leadingImage
            })
            tf.rightViewMode = leadingImage != nil ? .always : .never
        }

        // Re-apply NeoPop border whenever borderColor changes
        container.applyNeoPopStyle(model: PopView.Model(
            popEdgeDirection:    .bottomRight,
            backgroundColor:     .popBlack,
            verticalEdgeColor:   PopHelper.verticalEdgeColor(for: borderColor),
            horizontalEdgeColor: PopHelper.horizontalEdgeColor(for: borderColor)
        ))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onCommit: (() -> Void)?

        init(text: Binding<String>, onCommit: (() -> Void)?) {
            _text         = text
            self.onCommit = onCommit
        }

        @objc func changed(_ tf: UITextField) { text = tf.text ?? "" }

        func textFieldShouldReturn(_ tf: UITextField) -> Bool {
            tf.resignFirstResponder()
            onCommit?()
            return true
        }
    }
}
