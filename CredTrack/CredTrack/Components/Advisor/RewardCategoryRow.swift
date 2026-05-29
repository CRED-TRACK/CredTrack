import SwiftUI

/// One reward category row inside a per-card section on the Advisor screen.
struct RewardCategoryRow: View {
    let rule: AdvisorRewardRuleDTO
    var isGlobalBest: Bool = false

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: rule.iconHint ?? "creditcard.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.ctTextSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.displayName)
                        .font(.ctTitle)
                        .foregroundColor(.ctTextPrimary)
                    if let label = badgeSubtitle() {
                        Text(label)
                            .font(.ctCaption)
                            .foregroundColor(.ctTextSecondary)
                    }
                }

                Spacer()

                Text(rule.rateLabel)
                    .font(.ctHeadline)
                    .foregroundColor(.ctTextPrimary)

                if isGlobalBest { BestCardBadge() }
            }

            if rule.capAmount != nil {
                CapProgressBar(
                    spent: rule.spentInPeriod,
                    cap: rule.capAmount,
                    periodLabel: rule.capPeriodLabel,
                    exhausted: rule.capExhausted
                )
            }

            if expanded {
                if let notes = rule.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.ctBody)
                        .foregroundColor(.ctTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !rule.exclusions.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Excludes")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                        ForEach(rule.exclusions, id: \.self) { ex in
                            Text("• " + ex.replacingOccurrences(of: "_", with: " "))
                                .font(.ctCaption)
                                .foregroundColor(.ctTextSecondary)
                        }
                    }
                }
                if rule.source != "SEED" {
                    Text("Source: \(rule.source.lowercased())")
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.ctSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { expanded.toggle() } }
    }

    private func badgeSubtitle() -> String? {
        if rule.requiresUserChoice && rule.userChoiceActive != rule.canonicalCategory {
            return "Pick this as your 3% to activate"
        }
        if let restriction = rule.channelRestriction, restriction == "TRAVEL_PORTAL_ONLY" {
            return "Via Chase Travel only"
        }
        if rule.capExhausted { return "Cap reached" }
        return nil
    }
}
