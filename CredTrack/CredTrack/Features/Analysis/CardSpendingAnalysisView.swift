import SwiftUI
import Charts

struct CardSpendingAnalysisView: View {

    @State private var months:  Int = 6
    @State private var data:    CardSpendingResponseDTO? = nil
    @State private var loading  = false
    @State private var errorMsg: String? = nil

    private let monthOptions = [1, 3, 6, 12]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                periodPicker
                    .padding(.top, 16)

                if loading {
                    ProgressView()
                        .tint(.ctTextSecondary)
                        .padding(.top, 60)
                } else if let err = errorMsg {
                    emptyState(icon: "exclamationmark.circle", message: err)
                } else if let d = data {
                    let mb = d.monthlyBreakdown ?? []
                    if mb.isEmpty && d.cards.isEmpty {
                        emptyState(icon: "creditcard",
                                   message: "No statement data for the last \(months) month\(months == 1 ? "" : "s").")
                    } else {
                        Group {
                            totalHeader(d)
                            // 1M: single period — bar chart is meaningless, show per-card breakdown
                            if months == 1 || mb.isEmpty {
                                if !d.cards.isEmpty { cardSummaryList(d.cards) }
                            } else {
                                if !mb.isEmpty    { monthlyChart(mb) }
                                if !d.cards.isEmpty { cardSummaryList(d.cards) }
                            }
                        }
                        .id(months)
                    }
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .task(id: months) { await load() }
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(monthOptions, id: \.self) { m in
                Button { withAnimation { months = m } } label: {
                    Text("\(m)M")
                        .font(.ctCaption)
                        .foregroundColor(months == m ? .ctTextPrimary : .ctTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(months == m ? Color.NeoPop.PoliPurple.c400.opacity(0.25) : Color.NeoPop.Black.c300)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(
                            months == m ? Color.NeoPop.PoliPurple.c400 : Color.clear,
                            lineWidth: 1))
                }
            }
            Spacer()
        }
    }

    // MARK: - Total header

    private func totalHeader(_ d: CardSpendingResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total Spent")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
            Text(formatCurrency(d.totalSpend))
                .font(.ctSerif)
                .foregroundColor(.ctTextPrimary)
            Text("Statement totals · last \(d.months) month\(d.months == 1 ? "" : "s")")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.ctSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Month-on-month bar chart

    private func monthlyChart(_ breakdown: [CardSpendingResponseDTO.MonthlyBreakdownDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MONTH ON MONTH")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            Chart(breakdown) { month in
                BarMark(
                    x: .value("Month", monthLabel(month.month)),
                    y: .value("Spend", month.totalSpend)
                )
                .foregroundStyle(Color.NeoPop.PoliPurple.c400)
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center) {
                    Text(formatCurrencyShort(month.totalSpend))
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.ctTextSecondary)
                        .font(.ctMicro)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 180)
            .padding(16)
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Month detail rows — most recent first
            VStack(spacing: 0) {
                ForEach(Array(breakdown.reversed().enumerated()), id: \.element.id) { idx, month in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.NeoPop.PoliPurple.c400)
                            .frame(width: 3, height: 18)
                        Text(monthLabelFull(month.month))
                            .font(.ctBody)
                            .foregroundColor(.ctTextPrimary)
                        Spacer()
                        Text(formatCurrency(month.totalSpend))
                            .font(.ctBodyMedium)
                            .foregroundColor(.ctTextPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)

                    if idx < breakdown.count - 1 {
                        Divider().background(Color.NeoPop.Black.c200).padding(.leading, 35)
                    }
                }
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Card summary list

    private func cardSummaryList(_ cards: [CardSpendingResponseDTO.CardSummaryDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY CARD")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(cardColor(for: card.bankKey))
                            .frame(width: 10, height: 10)
                        Text(cardLabel(card))
                            .font(.ctBody)
                            .foregroundColor(.ctTextPrimary)
                        Spacer()
                        Text(formatCurrency(card.totalSpend))
                            .font(.ctBodyMedium)
                            .foregroundColor(.ctTextPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if idx < cards.count - 1 {
                        Divider().background(Color.NeoPop.Black.c200).padding(.leading, 38)
                    }
                }
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.ctMicro)
            .foregroundColor(.ctTextSecondary)
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.ctTextSecondary)
            Text(message)
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    /// "2025-11" → "Nov"
    private func monthLabel(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]) else { return raw }
        let symbols = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return m >= 1 && m <= 12 ? symbols[m - 1] : raw
    }

    /// "2025-11" → "November 2025"
    private func monthLabelFull(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]), let y = Int(parts[0]) else { return raw }
        let names = ["January","February","March","April","May","June",
                     "July","August","September","October","November","December"]
        return m >= 1 && m <= 12 ? "\(names[m - 1]) \(y)" : raw
    }

    private func cardLabel(_ card: CardSpendingResponseDTO.CardSummaryDTO) -> String {
        "\(bankDisplayName(card.bankKey)) ••••\(card.lastFour)"
    }

    private func bankDisplayName(_ key: String) -> String {
        switch key {
        case "AMEX":        return "Amex"
        case "BOA":         return "BofA"
        case "CHASE":       return "Chase"
        case "DISCOVER":    return "Discover"
        case "CITI":        return "Citi"
        case "CAPITAL_ONE": return "Cap One"
        case "WELLS_FARGO": return "Wells Fargo"
        default:            return key
        }
    }

    private func cardColor(for bankKey: String) -> Color {
        switch bankKey {
        case "AMEX":        return Color.NeoPop.PoliPurple.c400
        case "BOA":         return Color.NeoPop.OrangeSunshine.c400
        case "CHASE":       return Color.NeoPop.PinkPong.c400
        case "DISCOVER":    return Color.NeoPop.NeoPaccha.c400
        case "CITI":        return Color.NeoPop.Yoyo.c400
        case "CAPITAL_ONE": return Color.NeoPop.ParkGreen.c400
        default:            return Color.NeoPop.White.c100
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }

    private func formatCurrencyShort(_ v: Double) -> String {
        v >= 1_000 ? String(format: "$%.1fK", v / 1_000) : String(format: "$%.0f", v)
    }

    // MARK: - Data loading

    @MainActor
    private func load() async {
        loading  = true
        errorMsg = nil
        defer { loading = false }
        do {
            let result = try await APIClient.shared.fetchCardSpending(months: months)
            withAnimation { data = result }
        } catch is CancellationError {
            return
        } catch {
            errorMsg = "Could not load analytics."
        }
    }
}
