import SwiftUI
import UIKit

struct CardDetailView: View {
    let card: UserCardDTO
    @Environment(\.dismiss) private var dismiss

    @State private var tooltipExpanded         = false
    @State private var statements:             [CardStatementDTO] = []
    @State private var totalStatements:        Int = 0
    @State private var statementsLoading       = false
    @State private var navigateToAllStatements = false

    private var model: CardModel { card.toCardModel() }

    // MARK: - Utilization

    private var utilization: Double? {
        guard let balance = card.currentBalance,
              let limit   = card.creditLimit, limit > 0 else { return nil }
        return min((balance / limit) * 100, 100)
    }

    /// Color thresholds sourced from FICO / Experian research:
    /// < 10% Excellent · 10-29% Good · 30-49% Fair · 50-74% Poor · ≥ 75% Very Poor
    private var utilizationColor: Color {
        guard let u = utilization else { return Color.NeoPop.Black.c100 }
        switch u {
        case ..<10:  return Color(UIColor.NeoPop.State.success300)   // Excellent
        case ..<30:  return Color(UIColor.NeoPop.State.success400)   // Good
        case ..<50:  return Color(UIColor.NeoPop.State.warning300)   // Fair
        case ..<75:  return Color(UIColor.NeoPop.State.error300)     // Poor
        default:     return Color(UIColor.NeoPop.State.error500)     // Very Poor
        }
    }

    private var utilizationLabel: String {
        guard let u = utilization else { return "N/A" }
        switch u {
        case ..<10:  return "EXCELLENT"
        case ..<30:  return "GOOD"
        case ..<50:  return "FAIR"
        case ..<75:  return "POOR"
        default:     return "VERY POOR"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // ── Nav bar ──────────────────────────────────────────────────────────
            HStack {
                CTBackButton { dismiss() }
                Spacer()
                statusBadge
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // ── Scrollable content ───────────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    cardHero
                        .padding(.top, 16)
                        .padding(.bottom, 36)

                    statsRow
                    Spacer().frame(height: 32)
                    paymentSection
                    statementsSection
                    infoSection
                    Spacer().frame(height: 56)
                }
            }
        }
        .background(
            VStack(spacing: 0) {
                Color(hex: card.faceColor)
                    .opacity(0.18)
                    .frame(height: 320)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Color.ctBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Color.ctBackground
            }
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .task {
            statementsLoading = true
            if let page = try? await APIClient.shared.fetchStatements(cardId: card.id, size: 5) {
                statements      = page.content
                totalStatements = page.totalElements
            }
            statementsLoading = false
        }
    }

    // MARK: - Card hero

    private var cardHero: some View {
        // ZStack lets the tooltip overflow below the card edge
        ZStack(alignment: .bottomLeading) {
            // Card + progress bar overlay
            CreditCardView(card: model, isPressed: false)
                .frame(width: cardWidth, height: cardHeight)
                .overlay(alignment: .bottom) {
                    utilizationBar
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color(hex: card.faceColor).opacity(0.30),
                        radius: 20, x: 0, y: 10)

            // Expandable tooltip — sits at bottom-left, can grow downward
            if card.creditLimit != nil {
                utilizationTooltip
                    .padding(.leading, 16)
                    .padding(.bottom, 20)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8),
                               value: tooltipExpanded)
            }
        }
    }

    // MARK: - Progress bar (overlaid on card bottom edge)
    // GeometryReader reports zero width inside .overlay, so we use the known cardWidth constant.

    private var utilizationBar: some View {
        ZStack(alignment: .leading) {
            // Track — full card width
            Color.black.opacity(0.35)
                .frame(width: cardWidth, height: 6)
            // Fill — proportional to utilization
            if let u = utilization {
                utilizationColor
                    .frame(width: cardWidth * CGFloat(u / 100), height: 6)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: u)
            }
        }
        .frame(width: cardWidth, height: 6)
    }

    // MARK: - Expandable tooltip

    private var utilizationTooltip: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Always-visible row
            HStack(spacing: 7) {
                Circle()
                    .fill(utilizationColor)
                    .frame(width: 8, height: 8)

                if tooltipExpanded {
                    Text("\(formattedUtilization) · \(utilizationLabel)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text(formattedUtilization)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Image(systemName: tooltipExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Expanded detail
            if tooltipExpanded,
               let balance = card.currentBalance,
               let limit   = card.creditLimit {
                Text("\(formatCurrency(balance)) of \(formatCurrency(limit)) used")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.65))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tooltipExpanded.toggle()
            }
        }
    }

    private var formattedUtilization: String {
        guard let u = utilization else { return "—" }
        return String(format: "%.1f%%", u)
    }

    // MARK: - Stats row  (LIMIT · SPENT · UTILIZED)

    private var statsRow: some View {
        HStack(spacing: 12) {
            DetailStatTile(
                value: card.creditLimit.map { formatCurrency($0) } ?? "—",
                label: "LIMIT"
            )
            .frame(maxWidth: .infinity, minHeight: 80)

            DetailStatTile(
                value: card.currentBalance.map { formatCurrency($0) } ?? "—",
                label: "SPENT"
            )
            .frame(maxWidth: .infinity, minHeight: 80)

            DetailStatTile(
                value: utilization.map { String(format: "%.1f%%", $0) } ?? "—",
                label: "UTILIZED",
                valueColor: utilization != nil ? UIColor(utilizationColor) : nil
            )
            .frame(maxWidth: .infinity, minHeight: 80)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Card info section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CARD INFO")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 4)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                if let name = card.cardHolderName {
                    DetailInfoRow(icon: "person.fill",        label: "Cardholder",  value: name)
                    rowDivider
                }
                if let last4 = card.lastFour {
                    DetailInfoRow(icon: "number",             label: "Card Number", value: "•••• •••• •••• \(last4)")
                    rowDivider
                }
                DetailInfoRow(icon: "building.columns.fill", label: "Issuer",      value: card.issuerName)
                rowDivider
                DetailInfoRow(icon: "creditcard.fill",       label: "Network",     value: card.brand.capitalized)
                rowDivider
                DetailInfoRow(icon: "tag.fill",              label: "Product",     value: card.productName)
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Payment info section

    @ViewBuilder
    private var paymentSection: some View {
        let hasAny = card.statementBalance != nil
                  || card.minimumDue != nil
                  || card.paymentDueDate != nil
                  || card.lastPaymentDate != nil
                  || card.lastPaymentAmount != nil
        if hasAny {
            VStack(alignment: .leading, spacing: 10) {
                Text("PAYMENT INFO")
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                    .padding(.leading, 4)
                    .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    if let sb = card.statementBalance {
                        DetailInfoRow(icon: "calendar.badge.clock",
                                      label: "Statement Balance",
                                      value: formatCurrency(sb))
                        if card.minimumDue != nil || card.paymentDueDate != nil
                            || card.lastPaymentDate != nil || card.lastPaymentAmount != nil {
                            rowDivider
                        }
                    }
                    if let md = card.minimumDue {
                        DetailInfoRow(icon: "exclamationmark.circle.fill",
                                      label: "Minimum Due",
                                      value: formatCurrency(md))
                        if card.paymentDueDate != nil
                            || card.lastPaymentDate != nil || card.lastPaymentAmount != nil {
                            rowDivider
                        }
                    }
                    if let pdd = card.paymentDueDate {
                        DetailInfoRow(icon: "calendar",
                                      label: "Payment Due",
                                      value: formatDate(pdd))
                        if card.lastPaymentDate != nil || card.lastPaymentAmount != nil {
                            rowDivider
                        }
                    }
                    if let lpd = card.lastPaymentDate, let lpa = card.lastPaymentAmount {
                        DetailInfoRow(icon: "banknote.fill",
                                      label: "Last Payment",
                                      value: "\(formatCurrency(lpa)) on \(formatDate(lpd))")
                    } else if let lpd = card.lastPaymentDate {
                        DetailInfoRow(icon: "banknote.fill",
                                      label: "Last Payment Date",
                                      value: formatDate(lpd))
                    } else if let lpa = card.lastPaymentAmount {
                        DetailInfoRow(icon: "banknote.fill",
                                      label: "Last Payment",
                                      value: formatCurrency(lpa))
                    }
                }
                .background(Color.ctSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1)
                )
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Statements section

    private var statementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Hidden programmatic NavigationLink for "View All"
            NavigationLink(
                destination: StatementsListView(card: card),
                isActive: $navigateToAllStatements
            ) { EmptyView() }
                .hidden()

            // Section header — "View All" NeoPop button on the right when needed
            HStack(alignment: .center) {
                Text("STATEMENTS")
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                    .padding(.leading, 4)
                Spacer()
                if totalStatements > 5 {
                    NeoPopElevatedButton(
                        title:          "View All",
                        faceColor:      .white,
                        labelColor:     .black,
                        superViewColor: .popDeepBlack,
                        fontSize:       12
                    ) {
                        navigateToAllStatements = true
                    }
                    .frame(width: 130, height: 34)
                }
            }
            .padding(.horizontal, 20)

            if statementsLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.ctTextSecondary)
                    Spacer()
                }
                .padding(.vertical, 28)
                .background(Color.ctSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
                .padding(.horizontal, 20)
            } else if statements.isEmpty {
                HStack {
                    Spacer()
                    Text("No statements yet")
                        .font(.ctBody)
                        .foregroundColor(.ctTextSecondary)
                    Spacer()
                }
                .padding(.vertical, 28)
                .background(Color.ctSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(statements.enumerated()), id: \.element.id) { index, stmt in
                        NavigationLink(destination: StatementDetailView(statement: stmt, card: card)) {
                            StatementRow(statement: stmt, formatCurrency: formatCurrency, formatDate: formatDate)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < statements.count - 1 {
                            rowDivider
                        }
                    }
                }
                .background(Color.ctSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Status badge

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(card.isActive
                      ? Color(UIColor.NeoPop.State.success300)
                      : Color(UIColor.NeoPop.State.error300))
                .frame(width: 7, height: 7)
            Text(card.isActive ? "ACTIVE" : "INACTIVE")
                .font(.ctMicro)
                .kerning(0.8)
                .foregroundColor(card.isActive
                                 ? Color(UIColor.NeoPop.State.success300)
                                 : Color(UIColor.NeoPop.State.error300))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill((card.isActive
                       ? Color(UIColor.NeoPop.State.success300)
                       : Color(UIColor.NeoPop.State.error300)).opacity(0.10))
                .overlay(
                    Capsule().strokeBorder(
                        (card.isActive
                         ? Color(UIColor.NeoPop.State.success300)
                         : Color(UIColor.NeoPop.State.error300)).opacity(0.30),
                        lineWidth: 1
                    )
                )
        )
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.1fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    private func formatDate(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }
}

// MARK: - Detail Info Row

private struct DetailInfoRow: View {
    let icon:  String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.ctTextPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.NeoPop.Black.c200))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                Text(value)
                    .font(.ctBody)
                    .foregroundColor(.ctTextPrimary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Statement Row

private struct StatementRow: View {
    let statement:     CardStatementDTO
    let formatCurrency: (Double) -> String
    let formatDate:     (String) -> String

    private var monthYear: String {
        guard let iso = statement.statementDate else { return "—" }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateFormat = "MMM yyyy"
        return display.string(from: date)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.ctTextPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.NeoPop.Black.c200))

            VStack(alignment: .leading, spacing: 3) {
                Text(monthYear)
                    .font(.ctBody)
                    .foregroundColor(.ctTextPrimary)
                HStack(spacing: 8) {
                    if let dd = statement.dueDate {
                        Text("Due \(formatDate(dd))")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                    if let md = statement.minimumDue {
                        Text("·")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                        Text("Min \(formatCurrency(md))")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let balance = statement.statementBalance {
                    Text(formatCurrency(balance))
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundColor(.ctTextPrimary)
                }
                if statement.isPaid == true {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(UIColor.NeoPop.State.success300))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Detail Stat Tile

private struct DetailStatTile: View {
    let value:      String
    let label:      String
    var valueColor: UIColor? = nil

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .default).weight(.bold))
                .foregroundColor(valueColor != nil ? Color(uiColor: valueColor!) : .ctTextPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.ctSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1)
        )
    }
}
