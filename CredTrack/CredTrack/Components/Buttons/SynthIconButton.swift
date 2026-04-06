import UIKit
import SwiftUI
import Synth

// MARK: - SynthIconButton
// A circular neumorphic icon button using Synth's elevatedSoft style.
// Used for close (✕) and back (←) actions throughout the app.
//
// Usage:
//   SynthIconButton(image: NeoPopIcons.closeUIImage, action: { dismiss() })
//       .frame(width: 44, height: 44)
//
//   SynthIconButton(image: NeoPopIcons.arrowUIImage, iconSize: 16, action: vm.back)
//       .frame(width: 44, height: 44)

struct SynthIconButton: UIViewRepresentable {
    let image:    UIImage?
    var iconSize: CGFloat = 14
    let action:   () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> UIButton {
        let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))

        // Synth elevatedSoft — icon only (no title)
        btn.applyNeuBtnStyle(
            type: .elevatedSoft,
            image: image?.withRenderingMode(.alwaysOriginal),
            imageDimension: iconSize
        )

        // Round shape — Synth sets masksToBounds = false so outer shadows survive
        btn.layer.cornerRadius = 22

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
