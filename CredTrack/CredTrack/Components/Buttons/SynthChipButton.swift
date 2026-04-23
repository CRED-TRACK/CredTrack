import UIKit
import SwiftUI
import Synth

// MARK: - SynthChipButton
// A compact neumorphic chip button using Synth's elevatedSoft style.
// Used in picker rows (period selector, account tabs).
//
// Usage:
//   SynthChipButton(label: "6M", isSelected: months == 6) { months = 6 }
//       .frame(height: 36)

struct SynthChipButton: UIViewRepresentable {
    let label:      String
    let isSelected: Bool
    let action:     () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> UIButton {
        let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 0, height: 36))
        btn.applyNeuBtnStyle(
            type: .elevatedSoft,
            attributedTitle: makeTitle(selected: isSelected)
        )
        btn.addTarget(context.coordinator,
                      action: #selector(Coordinator.tapped),
                      for: .touchUpInside)
        return btn
    }

    func updateUIView(_ btn: UIButton, context: Context) {
        let title = makeTitle(selected: isSelected)
        btn.setAttributedTitle(title, for: .normal)
        btn.setAttributedTitle(title, for: .highlighted)
    }

    private func makeTitle(selected: Bool) -> NSAttributedString {
        NSAttributedString(string: label, attributes: [
            .foregroundColor: selected ? UIColor.white : UIColor.NeoPop.Black.c100,
            .font: UIFont.gilroy(.semiBold, size: 12)
        ])
    }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
