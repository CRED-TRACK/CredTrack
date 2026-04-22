import Foundation
import SwiftUI

// MARK: - Biller visual config

enum BillerStyle {
    case eversource
    case nationalGrid

    init(billerName: String) {
        self = billerName.uppercased().contains("NATIONAL") ? .nationalGrid : .eversource
    }

    var backgroundGradient: LinearGradient {
        switch self {
        case .eversource:
            return LinearGradient(
                colors: [Color.white, Color(white: 0.91)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nationalGrid:
            return LinearGradient(
                colors: [
                    Color(red: 20 / 255, green: 85 / 255, blue: 186 / 255),
                    Color(red:  0 / 255, green: 46 / 255, blue: 140 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var logoAsset: String {
        switch self {
        case .eversource:   return "Eversource"
        case .nationalGrid: return "nationalgrid"
        }
    }

    var textColor: Color {
        switch self {
        case .eversource:   return Color(white: 0.18)
        case .nationalGrid: return .white
        }
    }

    var shadowColor: Color {
        switch self {
        case .eversource:   return .black.opacity(0.28)
        case .nationalGrid: return Color(red: 0, green: 0.18, blue: 0.55).opacity(0.50)
        }
    }

    var displayName: String {
        switch self {
        case .eversource:   return "EVERSOURCE"
        case .nationalGrid: return "NATIONAL GRID"
        }
    }

    /// Subtle tint for the detail-view hero background gradient.
    var tintColor: Color {
        switch self {
        case .eversource:   return Color(red: 0.13, green: 0.55, blue: 0.20)  // Eversource green
        case .nationalGrid: return Color(red: 20/255, green: 85/255, blue: 186/255)  // NGrid blue
        }
    }
}

// MARK: - UtilityCardView
//
// Displays a utility account as a credit-card-sized tile.
// Eversource: white card, logo centered filling almost full width (Discover-style).
// National Grid: brand blue card, same logo treatment.

struct UtilityCardView: View {
    let billerName:  String
    var lastFour:    String? = nil   // nil in picker/selector mode

    private var style: BillerStyle { BillerStyle(billerName: billerName) }

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 18)
                .fill(style.backgroundGradient)

            // ── Logo — almost full width, centered (Discover-style) ───────────
            Image(style.logoAsset)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 20)   // 20pt each side → ~88% of card width
                .frame(width: cardWidth, height: cardHeight)

            // ── Bottom-left: last four (shown only when account is linked) ────
            if let last4 = lastFour {
                VStack {
                    Spacer()
                    HStack {
                        Text("••••  ••••  ••••  \(last4)")
                            .font(.system(.caption, design: .monospaced).weight(.light))
                            .kerning(1.4)
                            .foregroundColor(style.textColor.opacity(0.80))
                            .padding(.leading, 20)
                            .padding(.bottom, 18)
                        Spacer()
                    }
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: style.shadowColor, radius: 14, x: 0, y: 7)
        .shadow(color: style.shadowColor.opacity(0.40), radius: 3,  x: 0, y: 1)
    }
}
