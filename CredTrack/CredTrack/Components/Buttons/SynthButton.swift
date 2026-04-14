import UIKit
import SwiftUI
import Synth

// MARK: - SynthButton
// A full-width neumorphic text button using Synth's elevatedSoft style.
//
// Usage:
//   SynthButton(title: "View All Statements") { navigate() }
//     .frame(height: 56)

struct SynthButton: UIViewRepresentable {
    let title:  String
    var height: CGFloat = 56
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> UIButton {
        let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 0, height: height))
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.gilroy(.semiBold, size: 15)
        ]
        btn.applyNeuBtnStyle(
            type: .elevatedSoft,
            attributedTitle: NSAttributedString(string: title, attributes: attrs)
        )
        btn.addTarget(context.coordinator,
                      action: #selector(Coordinator.tapped),
                      for: .touchUpInside)
        return btn
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
