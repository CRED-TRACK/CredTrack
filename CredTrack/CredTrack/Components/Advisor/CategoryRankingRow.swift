import SwiftUI

/// One row in the Advisor's category-first list.
/// Tap to expand all ranked cards for that category.
struct CategoryRankingRow: View {
    let group: AdvisorViewModel.CategoryGroup
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: group.iconHint)
                    .font(.system(size: 20))
                    .foregroundColor(.ctTextPrimary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.displayName)
                        .font(.ctTitle)
                        .foregroundColor(.ctTextPrimary)

                    if let best = group.best {
                        HStack(spacing: 6) {
                            Text(best.rateLabel)
                                .font(.ctCaption)
                                .foregroundColor(.NeoPop.NeoPaccha.c500)
                            Text(best.cardName)
                                .font(.ctCaption)
                                .foregroundColor(.ctTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    if let runner = group.runnerUp, runner.effectiveRateBps > 0 {
                        HStack(spacing: 6) {
                            Text(runner.rateLabel)
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                            Text("then \(runner.cardName)")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.ctTextSecondary)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)

            if expanded {
                Divider()
                    .background(Color.ctBackground)
                VStack(spacing: 0) {
                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { idx, entry in
                        rankedRow(rank: idx + 1, entry: entry)
                        if idx != group.entries.count - 1 {
                            Divider().background(Color.ctBackground)
                        }
                    }
                }
            }
        }
        .background(Color.ctSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { expanded.toggle() } }
    }

    private func rankedRow(rank: Int, entry: AdvisorViewModel.RankedEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(rank).")
                .font(.ctCaption)
                .foregroundColor(.ctTextSecondary)
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.cardName)
                    .font(.ctBodyMedium)
                    .foregroundColor(entry.blocked ? .ctTextSecondary : .ctTextPrimary)
                    .lineLimit(1)
                if let detail = subtitle(for: entry) {
                    Text(detail)
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(entry.rateLabel)
                .font(.ctTitle)
                .foregroundColor(entry.blocked || entry.capExhausted
                                 ? .ctTextSecondary
                                 : .ctTextPrimary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private func subtitle(for entry: AdvisorViewModel.RankedEntry) -> String? {
        if entry.blocked        { return "Requires category choice" }
        if entry.capExhausted   { return "Cap reached" }
        if let rem = entry.capRemaining, rem > 0 {
            let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
            let cap = f.string(from: NSNumber(value: rem)) ?? "\(Int(rem))"
            return "$\(cap) left"
        }
        if let last = entry.lastFour { return "•••• \(last)" }
        return nil
    }
}
