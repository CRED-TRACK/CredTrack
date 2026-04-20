import SwiftUI

struct StatementDetailView: View {
    let statement: CardStatementDTO
    let card:      UserCardDTO

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    balanceHero
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    detailsSection
                    Spacer().frame(height: 32)
                    actionButtons
                    Spacer().frame(height: 48)
                }
            }
        }
        .background(
            VStack(spacing: 0) {
                Color(hex: card.faceColor)
                    .opacity(0.12)
                    .frame(height: 260)
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
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            CTBackButton { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text(monthYear)
                    .font(.ctTitle)
                    .foregroundColor(.ctTextPrimary)
                Text(card.nickname ?? card.productName)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
            }
            Spacer()
            CTBackButton { dismiss() }
                .opacity(0)
                .disabled(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Balance hero

    private var balanceHero: some View {
        VStack(spacing: 6) {
            if let balance = statement.statementBalance {
                Text(formatCurrency(balance))
                    .font(.system(size: 44, weight: .bold, design: .default))
                    .foregroundColor(.ctTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.ctTextSecondary)
            }
            Text("Statement Balance")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
        }
    }

    // MARK: - Details section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("DETAILS")
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                    .padding(.leading, 4)
                Spacer()
                if let urlStr = statement.viewStatementUrl, let link = URL(string: urlStr) {
                    NeoPopElevatedButton(
                        title:          "View Statement",
                        faceColor:      .white,
                        labelColor:     .black,
                        superViewColor: .popDeepBlack,
                        fontSize:       12
                    ) {
                        UIApplication.shared.open(link)
                    }
                    .frame(width: 140, height: 34)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                if let sd = statement.statementDate {
                    StmtInfoRow(icon: "doc.text.fill",
                                label: "Statement Date",
                                value: formatDate(sd))
                    divider
                }

                if let dd = statement.dueDate {
                    StmtInfoRow(icon: "calendar",
                                label: "Payment Due",
                                value: formatDate(dd),
                                valueColor: dueDateColor)
                    if statement.minimumDue != nil || statement.bank != nil { divider }
                }

                if let md = statement.minimumDue {
                    StmtInfoRow(icon: "exclamationmark.circle.fill",
                                label: "Minimum Due",
                                value: formatCurrency(md))
                    if statement.bank != nil { divider }
                }

                if let bank = statement.bank {
                    StmtInfoRow(icon: "building.columns.fill",
                                label: "Bank",
                                value: bank)
                }

                if statement.isPaid == true {
                    divider
                    if let pd = statement.paymentDate {
                        StmtInfoRow(icon: "checkmark.circle.fill",
                                    label: "Payment Date",
                                    value: formatDate(pd),
                                    valueColor: Color(UIColor.NeoPop.State.success300))
                    }
                    if let pa = statement.paidAmount {
                        divider
                        StmtInfoRow(icon: "dollarsign.circle.fill",
                                    label: "Amount Paid",
                                    value: formatCurrency(pa),
                                    valueColor: Color(UIColor.NeoPop.State.success300))
                    }
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
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        if let urlStr = statement.makePaymentUrl, let link = URL(string: urlStr) {
            NeoPopFloatingButton(
                title:      "Pay Now",
                shimmer:    true,
                faceColor:  UIColor.NeoPop.State.success300,
                labelColor: .white,
                showArrow:  false
            ) {
                UIApplication.shared.open(link)
            }
            .frame(height: 56)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }

    private var monthYear: String {
        guard let iso = statement.statementDate else { return "Statement" }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateFormat = "MMM yyyy"
        return display.string(from: date)
    }

    private var dueDateColor: Color? {
        guard let iso = statement.dueDate else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let due = parser.date(from: iso) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: due).day ?? 0
        if days < 0  { return Color(UIColor.NeoPop.State.error500) }   // overdue
        if days <= 5 { return Color(UIColor.NeoPop.State.error300) }   // due soon
        if days <= 10 { return Color(UIColor.NeoPop.State.warning300) }
        return nil
    }

    private func formatCurrency(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "$%.1fK", v / 1_000) }
        return String(format: "$%.2f", v)
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

// MARK: - Statement Info Row

private struct StmtInfoRow: View {
    let icon:       String
    let label:      String
    let value:      String
    var valueColor: Color? = nil

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
                    .foregroundColor(valueColor ?? .ctTextPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
