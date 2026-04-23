import UIKit
import SwiftUI
import Synth

// MARK: - SynthTabContainer
// Deferred-layout host for the inner UIButton.
// applyNeuBtnStyle must NOT be called until bounds are non-zero (same pattern as
// PopButtonHost in NeoPopComponents.swift — Synth's CAGradientLayer crashes on NaN
// when configured with a zero frame).

final class SynthTabContainer: UIView {
    let button = UIButton()
    var onFirstLayout: (() -> Void)?
    private var configured = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty, !configured else { return }
        configured = true
        onFirstLayout?()
    }

    var isConfigured: Bool { configured }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 48)
    }
}

// MARK: - SynthTabButton

struct SynthTabButton: UIViewRepresentable {
    let title:      String
    let isSelected: Bool
    let action:     () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> SynthTabContainer {
        let container = SynthTabContainer()
        container.button.addTarget(context.coordinator,
                                   action: #selector(Coordinator.tapped),
                                   for: .touchUpInside)
        // Capture current value-type self so the closure uses the correct initial state
        let snapshot = self
        container.onFirstLayout = { [weak container] in
            guard let btn = container?.button else { return }
            snapshot.applyStyle(to: btn)
        }
        return container
    }

    func updateUIView(_ container: SynthTabContainer, context: Context) {
        if container.isConfigured {
            // Bounds are real — apply immediately
            applyStyle(to: container.button)
        } else {
            // Not yet laid out — update the deferred closure with latest state
            let snapshot = self
            container.onFirstLayout = { [weak container] in
                guard let btn = container?.button else { return }
                snapshot.applyStyle(to: btn)
            }
        }
    }

    private func applyStyle(to btn: UIButton) {
        btn.applyNeuBtnStyle(
            type: isSelected ? .elevatedFlat : .elevatedSoft,
            attributedTitle: NSAttributedString(string: title, attributes: [
                .foregroundColor: isSelected ? UIColor.white : UIColor.NeoPop.Black.c100,
                .font: UIFont.gilroy(.semiBold, size: 14)
            ])
        )
    }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
