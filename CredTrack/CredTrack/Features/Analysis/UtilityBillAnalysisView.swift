import SwiftUI
import Charts

struct UtilityBillAnalysisView: View {

    @State private var data:       UtilityAnalyticsResponseDTO? = nil
    @State private var loading     = false
    @State private var errorMsg:   String? = nil
    // -1 = Combined (default when >1 account); 0..n = individual account index
    @State private var selectedIdx = -1

    private let accentColors: [Color] = [
        Color.NeoPop.PoliPurple.c400,
        Color.NeoPop.OrangeSunshine.c400,
        Color.NeoPop.PinkPong.c400,
        Color.NeoPop.NeoPaccha.c400
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 4)

                if loading {
                    ProgressView()
                        .tint(.ctTextSecondary)
                        .padding(.top, 60)
                } else if let err = errorMsg {
                    emptyState(icon: "exclamationmark.circle", message: err)
                } else if let d = data, !d.accounts.isEmpty {
                    let accounts = d.accounts
                    if accounts.count > 1 {
                        accountPicker(accounts)
                    }

                    if selectedIdx == -1 && accounts.count > 1 {
                        combinedContent(accounts)
                    } else {
                        let idx = max(0, min(selectedIdx, accounts.count - 1))
                        accountContent(accounts[idx], color: accentColors[min(idx, accentColors.count - 1)])
                    }
                } else {
                    emptyState(icon: "bolt.slash", message: "No utility bills recorded yet.")
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .task { await load() }
    }

    // MARK: - Account picker (Combined + individual)

    private func accountPicker(_ accounts: [UtilityAnalyticsResponseDTO.AccountSummaryDTO]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "Combined", selected: selectedIdx == -1) {
                    withAnimation { selectedIdx = -1 }
                }
                ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, account in
                    chipButton(label: accountLabel(account), selected: selectedIdx == idx) {
                        withAnimation { selectedIdx = idx }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func chipButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.ctCaption)
                .foregroundColor(selected ? .ctTextPrimary : .ctTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.NeoPop.PoliPurple.c400.opacity(0.25) : Color.NeoPop.Black.c300)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(
                    selected ? Color.NeoPop.PoliPurple.c400 : Color.clear,
                    lineWidth: 1))
        }
    }

    // MARK: - Combined view

    private func combinedContent(_ accounts: [UtilityAnalyticsResponseDTO.AccountSummaryDTO]) -> some View {
        VStack(spacing: 20) {
            combinedSummaryRow(accounts)
            let hasEnough = accounts.contains(where: { $0.bills.count >= 2 })
            if hasEnough {
                combinedTrendChart(accounts)
                combinedLineChart(accounts)
            }
        }
    }

    private func combinedSummaryRow(_ accounts: [UtilityAnalyticsResponseDTO.AccountSummaryDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL UTILITIES")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            VStack(spacing: 0) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, account in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(accentColors[min(idx, accentColors.count - 1)])
                            .frame(width: 8, height: 8)
                        Text(accountLabel(account))
                            .font(.ctBody)
                            .foregroundColor(.ctTextPrimary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(account.latestAmount.map { formatCurrency($0) } ?? "—")
                                .font(.ctBodyMedium)
                                .foregroundColor(.ctTextPrimary)
                            Text("avg \(formatCurrency(account.averageAmount))")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if idx < accounts.count - 1 {
                        Divider().background(Color.NeoPop.Black.c200).padding(.leading, 36)
                    }
                }
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func combinedTrendChart(_ accounts: [UtilityAnalyticsResponseDTO.AccountSummaryDTO]) -> some View {
        let cutoff = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()

        struct BarPoint: Identifiable {
            let id = UUID()
            let month: Date
            let accountName: String
            let amount: Double
        }

        var points: [BarPoint] = []
        for (idx, account) in accounts.enumerated() {
            let name = billerDisplayName(account.billerName)
            var monthlyTotals: [String: Double] = [:]
            for bill in account.bills {
                guard let d = parseDate(bill.billDate), d >= cutoff else { continue }
                let key = bill.billDate.prefix(7).description
                monthlyTotals[key, default: 0] += bill.amountDue
            }
            for (monthStr, total) in monthlyTotals {
                if let d = parseDate("\(monthStr)-01") {
                    points.append(BarPoint(month: d, accountName: name, amount: total))
                }
            }
            _ = idx
        }
        points.sort { $0.month < $1.month }

        let colorScale: KeyValuePairs<String, Color> = [
            billerDisplayName(accounts[0].billerName): accentColors[0],
            accounts.count > 1 ? billerDisplayName(accounts[1].billerName) : "": accentColors[1]
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text("MONTHLY TOTAL")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            HStack(spacing: 16) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, account in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accentColors[min(idx, accentColors.count - 1)])
                            .frame(width: 6, height: 6)
                        Text(billerDisplayName(account.billerName))
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                }
                Spacer()
            }

            Chart(points) { pt in
                BarMark(
                    x: .value("Month", pt.month, unit: .month),
                    y: .value("Amount", pt.amount)
                )
                .foregroundStyle(by: .value("Account", pt.accountName))
                .cornerRadius(4)
            }
            .chartForegroundStyleScale(colorScale)
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Color.ctTextSecondary)
                        .font(.ctMicro)
                    AxisGridLine().foregroundStyle(Color.NeoPop.Black.c200)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatCurrencyShort(v))
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                        }
                    }
                    AxisGridLine().foregroundStyle(Color.NeoPop.Black.c200)
                }
            }
            .frame(height: 200)
            .padding(16)
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func combinedLineChart(_ accounts: [UtilityAnalyticsResponseDTO.AccountSummaryDTO]) -> some View {
        let cutoff = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()

        return VStack(alignment: .leading, spacing: 12) {
            Text("TREND (5 MONTHS)")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            HStack(spacing: 16) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, account in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accentColors[min(idx, accentColors.count - 1)])
                            .frame(width: 6, height: 6)
                        Text(billerDisplayName(account.billerName))
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                }
                Spacer()
            }

            Chart {
                ForEach(Array(accounts.enumerated()), id: \.offset) { idx, account in
                    let color = accentColors[min(idx, accentColors.count - 1)]
                    let seriesName = billerDisplayName(account.billerName)
                    let points = account.bills.compactMap { b -> (Date, Double)? in
                        guard let d = parseDate(b.billDate), d >= cutoff else { return nil }
                        return (d, b.amountDue)
                    }.sorted { $0.0 < $1.0 }
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        LineMark(
                            x: .value("Date",   pt.0),
                            y: .value("Amount", pt.1),
                            series: .value("Account", seriesName)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(24)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Color.ctTextSecondary)
                        .font(.ctMicro)
                    AxisGridLine().foregroundStyle(Color.NeoPop.Black.c200)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatCurrencyShort(v))
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                        }
                    }
                    AxisGridLine().foregroundStyle(Color.NeoPop.Black.c200)
                }
            }
            .frame(height: 200)
            .padding(16)
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Individual account content

    private func accountContent(_ account: UtilityAnalyticsResponseDTO.AccountSummaryDTO,
                                 color: Color) -> some View {
        VStack(spacing: 20) {
            statsHeader(account, color: color)
            if account.bills.count >= 2 {
                billTrendChart(account.bills, color: color)
            }
            billHistoryList(account.bills)
        }
    }

    // MARK: - Stats header

    private func statsHeader(_ account: UtilityAnalyticsResponseDTO.AccountSummaryDTO,
                              color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(accountLabel(account).uppercased())
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            HStack(spacing: 0) {
                statCell(label: "Latest Bill",
                         value: account.latestAmount.map { formatCurrency($0) } ?? "—",
                         highlight: true)
                dividerLine
                statCell(label: "Monthly Avg",
                         value: formatCurrency(account.averageAmount))
                dividerLine
                statCell(label: "vs Prev",
                         value: changeLabel(account.changePercent),
                         valueColor: changeColor(account.changePercent))
            }
            .padding(.vertical, 4)
        }
        .padding(20)
        .background(Color.ctSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statCell(label: String, value: String,
                          highlight: Bool = false,
                          valueColor: Color = .ctTextPrimary) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
            Text(value)
                .font(highlight ? .ctTitle : .ctBodyMedium)
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Individual trend chart

    private func billTrendChart(_ bills: [UtilityAnalyticsResponseDTO.AccountSummaryDTO.BillPointDTO],
                                 color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BILL TREND")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            let points = bills.compactMap { b -> (Date, Double)? in
                guard let d = parseDate(b.billDate) else { return nil }
                return (d, b.amountDue)
            }

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                    LineMark(
                        x: .value("Date",   pt.0),
                        y: .value("Amount", pt.1)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .symbolSize(30)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: max(1, points.count / 4))) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Color.ctTextSecondary)
                        .font(.ctMicro)
                    AxisGridLine().foregroundStyle(Color.NeoPop.Black.c200)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatCurrencyShort(v))
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                        }
                    }
                    AxisGridLine().foregroundStyle(Color.NeoPop.Black.c200)
                }
            }
            .frame(height: 200)
            .padding(16)
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Bill history list

    private func billHistoryList(_ bills: [UtilityAnalyticsResponseDTO.AccountSummaryDTO.BillPointDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BILL HISTORY")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)

            let reversed = bills.reversed()
            VStack(spacing: 0) {
                ForEach(Array(reversed.enumerated()), id: \.offset) { idx, bill in
                    HStack {
                        Text(formatDisplayDate(bill.billDate))
                            .font(.ctBody)
                            .foregroundColor(.ctTextPrimary)
                        Spacer()
                        Text(formatCurrency(bill.amountDue))
                            .font(.ctBodyMedium)
                            .foregroundColor(.ctTextPrimary)

                        if idx < reversed.count - 1 {
                            let prev = Array(reversed)[idx + 1].amountDue
                            let delta = bill.amountDue - prev
                            Text(deltaLabel(delta))
                                .font(.ctMicro)
                                .foregroundColor(delta > 0
                                    ? Color(UIColor.NeoPop.State.error300)
                                    : Color(UIColor.NeoPop.State.success300))
                                .frame(width: 52, alignment: .trailing)
                        } else {
                            Text("").frame(width: 52)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)

                    if idx < reversed.count - 1 {
                        Divider().background(Color.NeoPop.Black.c200)
                    }
                }
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

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

    private func accountLabel(_ account: UtilityAnalyticsResponseDTO.AccountSummaryDTO) -> String {
        "\(billerDisplayName(account.billerName)) ••••\(account.accountLastFour)"
    }

    private func billerDisplayName(_ name: String) -> String {
        switch name.uppercased() {
        case "EVERSOURCE":    return "Eversource"
        case "NATIONAL_GRID": return "National Grid"
        default:              return name.capitalized
        }
    }

    private func changeLabel(_ pct: Double?) -> String {
        guard let p = pct else { return "—" }
        return p >= 0 ? String(format: "+%.1f%%", p) : String(format: "%.1f%%", p)
    }

    private func changeColor(_ pct: Double?) -> Color {
        guard let p = pct else { return .ctTextSecondary }
        return p > 0 ? Color(UIColor.NeoPop.State.error300) : Color(UIColor.NeoPop.State.success300)
    }

    private func deltaLabel(_ delta: Double) -> String {
        if abs(delta) < 0.01 { return "—" }
        return delta > 0 ? String(format: "+$%.0f", delta) : String(format: "-$%.0f", abs(delta))
    }

    private func formatCurrency(_ v: Double) -> String { String(format: "$%.2f", v) }

    private func formatCurrencyShort(_ v: Double) -> String {
        v >= 1_000 ? String(format: "$%.1fK", v / 1_000) : String(format: "$%.0f", v)
    }

    private func parseDate(_ iso: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: iso)
    }

    private func formatDisplayDate(_ iso: String) -> String {
        guard let d = parseDate(iso) else { return iso }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    // MARK: - Data loading

    @MainActor
    private func load() async {
        loading  = true
        errorMsg = nil
        do {
            let result = try await APIClient.shared.fetchUtilityAnalytics()
            data = result
            // Default to combined when multiple accounts, else first account
            if result.accounts.count <= 1 {
                selectedIdx = 0
            }
        } catch {
            errorMsg = "Could not load analytics."
        }
        loading = false
    }
}
