import SwiftUI
import UIKit

/// One card row in "By card" view. Tap to expand → list of reward categories with rates.
struct CardSectionRow: View {
    let section: AdvisorCardSectionDTO
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: [
                            Color(uiColor: UIColor(hex: section.faceColor) ?? .darkGray),
                            Color(uiColor: UIColor(hex: section.gradientEnd) ?? .black)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.nickname ?? section.productName)
                        .font(.ctTitle)
                        .foregroundColor(.ctTextPrimary)
                    Text(subtitle())
                        .font(.ctCaption)
                        .foregroundColor(.ctTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.ctTextSecondary)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)

            if expanded {
                Divider().background(Color.ctBackground)

                if section.rewards.isEmpty {
                    Text("No rules yet — refresh after the next scrape.")
                        .font(.ctCaption)
                        .foregroundColor(.ctTextSecondary)
                        .padding(14)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(section.rewards.enumerated()), id: \.element.id) { idx, rule in
                            rewardRow(rule)
                            if idx != section.rewards.count - 1 {
                                Divider().background(Color.ctBackground)
                            }
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

    private func subtitle() -> String {
        let parts: [String] = [
            section.issuerName.capitalized,
            section.lastFour.map { "•••• \($0)" } ?? ""
        ].filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    private func rewardRow(_ rule: AdvisorRewardRuleDTO) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rule.iconHint ?? "creditcard.fill")
                .font(.system(size: 16))
                .foregroundColor(.ctTextSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                    .font(.ctBodyMedium)
                    .foregroundColor(rule.effectiveRateBps == 0 ? .ctTextSecondary : .ctTextPrimary)
                if let note = inlineDetail(rule) {
                    Text(note)
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(rule.rateLabel)
                .font(.ctTitle)
                .foregroundColor(rule.effectiveRateBps == 0 ? .ctTextSecondary : .ctTextPrimary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private func inlineDetail(_ rule: AdvisorRewardRuleDTO) -> String? {
        if rule.requiresUserChoice && rule.userChoiceActive != rule.canonicalCategory {
            return "Active only if chosen as 3% category"
        }
        if rule.channelRestriction == "TRAVEL_PORTAL_ONLY" {
            return "Via issuer travel portal only"
        }
        if rule.capExhausted { return "Cap reached" }
        if let rem = rule.capRemaining, rem > 0 {
            let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
            let cap = f.string(from: NSNumber(value: rem)) ?? "\(Int(rem))"
            let p = rule.capPeriodLabel ?? "left"
            return "$\(cap) \(p)"
        }
        return nil
    }
}
