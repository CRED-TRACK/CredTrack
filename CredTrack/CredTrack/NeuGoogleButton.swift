import SwiftUI
import Synth

struct NeuGoogleButton: UIViewRepresentable {

    let width: CGFloat
    let isLoading: Bool
    let action: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: width, height: 56))

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        button.applyNeuBtnStyle(
            type: .elevatedSoft,
            attributedTitle: NSAttributedString(string: "  Continue with Google", attributes: attrs),
            image: UIImage(named: "google_logo"),
            imageDimension: 22
        )
        button.tintColor = .white
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.isEnabled = !isLoading
        button.alpha = isLoading ? 0.5 : 1.0
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
