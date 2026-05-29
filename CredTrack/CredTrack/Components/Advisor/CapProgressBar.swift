import SwiftUI

/// Horizontal progress bar showing spent / cap for a capped reward category.
struct CapProgressBar: View {
    let spent: Double?
    let cap: Double?
    let periodLabel: String?
    let exhausted: Bool

    var body: some View {
        let s = max(0, spent ?? 0)
        let c = max(0, cap ?? 0)
        let raw = c > 0 ? s / c : 0
        let ratio: Double = raw.isFinite ? min(1.0, max(0, raw)) : 0
        let color: Color = exhausted ? .red
            : (ratio < 0.6 ? .green : (ratio < 0.9 ? .yellow : .orange))

        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.ctSurface)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * ratio))
                }
            }
            .frame(height: 6)

            Text(captionText(spent: s, cap: c))
                .font(.ctCaption)
                .foregroundColor(.ctTextSecondary)
        }
    }

    private func captionText(spent: Double, cap: Double) -> String {
        if exhausted {
            return "Cap exhausted — earning base rate"
        }
        let p = periodLabel ?? "this period"
        return "$\(format(spent)) / $\(format(cap)) \(p)"
    }

    private func format(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}
