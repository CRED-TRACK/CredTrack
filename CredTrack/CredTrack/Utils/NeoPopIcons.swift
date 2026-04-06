import SwiftUI
import UIKit

// MARK: - NeoPop Icons
// SVG paths sourced verbatim from github.com/CRED-CLUB/neopop-web
//
// All icons use template rendering — apply .foregroundColor() / .tint() in SwiftUI
// or .withRenderingMode(.alwaysTemplate) + .tintColor in UIKit.
//
// Usage (SwiftUI):
//   NeoPopIcons.close.foregroundColor(.white)
//   NeoPopIcons.chevron.foregroundColor(.ctTextSecondary)
//
// Usage (UIKit):
//   NeoPopIcons.closeUIImage?.withTintColor(.white)

enum NeoPopIcons {

    // ── SwiftUI Images ────────────────────────────────────────────────────────

    /// Left-pointing back arrow  (32 × 12, 3 stroke paths)
    /// Source: neopop-web / src/components/Back/index.tsx
    static let arrow      = Image("np_arrow")

    /// Close / X symbol  (12 × 12, 2 diagonal stroke paths)
    /// Source: neopop-web / src/components/Helpers/index.tsx → Cross
    static let close      = Image("np_close")

    /// Checkmark / tick  (10 × 8, 1 stroke path)
    /// Source: neopop-web / src/components/Checkbox/index.tsx
    static let checkmark  = Image("np_checkmark")

    /// Right-pointing chevron  (8 × 11, 1 stroke path)
    /// Source: neopop-web / src/components/Helpers/index.tsx → Chevron
    static let chevron    = Image("np_chevron")

    // ── UIKit Images (template mode) ─────────────────────────────────────────

    static var arrowUIImage:     UIImage? { UIImage(named: "np_arrow")?    .withRenderingMode(.alwaysTemplate) }
    static var closeUIImage:     UIImage? { UIImage(named: "np_close")?    .withRenderingMode(.alwaysTemplate) }
    static var checkmarkUIImage: UIImage? { UIImage(named: "np_checkmark")?.withRenderingMode(.alwaysTemplate) }
    static var chevronUIImage:   UIImage? { UIImage(named: "np_chevron")?  .withRenderingMode(.alwaysTemplate) }
}
