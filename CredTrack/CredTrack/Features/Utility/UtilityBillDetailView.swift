import SwiftUI

struct UtilityBillDetailView: View {
    @State var bill:    UtilityBillDTO
    let account:        UtilityAccountDTO

    @Environment(\.dismiss) private var dismiss

    @State private var showMarkPaidSheet = false
    @State private var isMarkingPaid     = false

    private var billerStyle: BillerStyle { BillerStyle(billerName: bill.billerName) }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    amountHero
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    detailsSection
                    if let payments = bill.payments, !payments.isEmpty {
                        Spacer().frame(height: 20)
                        paymentsSection(payments)
                    }
                    Spacer().frame(height: 48)
                }
            }
        }
        .background(
            VStack(spacing: 0) {
                billerStyle.tintColor
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
        .sheet(isPresented: $showMarkPaidSheet) {
            MarkUtilityPaidSheet(bill: bill) { date, amount in
                Task { await markPaid(date: date, amount: amount) }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            CTBackButton { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text(navHeading)
                    .font(.ctTitle)
                    .foregroundColor(.ctTextPrimary)
                Text(billerStyle.displayName)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
            }
            Spacer()
            if bill.isPaid == true {
                Label("Paid", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(UIColor.NeoPop.State.success300))
                    .transition(.scale.combined(with: .opacity))
            } else {
                NeoPopElevatedButton(
                    title:          "Mark as Paid",
                    faceColor:      .clear,
                    labelColor:     UIColor.NeoPop.State.success300,
                    superViewColor: .clear,
                    borderColor:    UIColor.NeoPop.State.success300,
                    fontSize:       12
                ) {
                    showMarkPaidSheet = true
                }
                .frame(width: 120, height: 34)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: bill.isPaid)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Amount hero

    private var amountHero: some View {
        VStack(spacing: 6) {
            if let amount = bill.amountDue {
                Text(formatCurrency(amount))
                    .font(.system(size: 44, weight: .bold, design: .default))
                    .foregroundColor(.ctTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.ctTextSecondary)
            }
            Text("Amount Due")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
        }
    }

    // MARK: - Details section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DETAILS")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 24)

            VStack(spacing: 0) {
                if let dd = bill.dueDate {
                    BillInfoRow(icon: "calendar",
                                label: "Due Date",
                                value: formatDate(dd),
                                valueColor: dueDateColor)
                    divider
                }

                if let start = bill.billingPeriodStart, let end = bill.billingPeriodEnd {
                    BillInfoRow(icon: "calendar.badge.clock",
                                label: "Billing Period",
                                value: "\(formatDate(start)) – \(formatDate(end))")
                    divider
                }

                if let bd = bill.billDate {
                    BillInfoRow(icon: "doc.text.fill",
                                label: "Bill Date",
                                value: formatDate(bd))
                    divider
                }

                BillInfoRow(icon: "building.2.fill",
                            label: "Provider",
                            value: billerStyle.displayName)
                divider

                BillInfoRow(icon: "number",
                            label: "Account",
                            value: "•••• \(bill.accountLastFour)")

                if bill.isPaid == true, let paid = bill.totalPaid, paid > 0 {
                    divider
                    BillInfoRow(icon: "dollarsign.circle.fill",
                                label: "Total Paid",
                                value: formatCurrency(paid),
                                valueColor: Color(UIColor.NeoPop.State.success300))
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

    // MARK: - Payment history section

    @ViewBuilder
    private func paymentsSection(_ payments: [UtilityPaymentDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PAYMENT HISTORY")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 24)

            VStack(spacing: 0) {
                ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(UIColor.NeoPop.State.success300))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.NeoPop.Black.c200))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Payment")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                            if let date = payment.paymentDate {
                                Text(formatDate(date))
                                    .font(.ctBody)
                                    .foregroundColor(.ctTextPrimary)
                            }
                        }
                        Spacer()
                        if let amount = payment.paymentAmount {
                            Text(formatCurrency(amount))
                                .font(.system(.body, design: .default).weight(.semibold))
                                .foregroundColor(Color(UIColor.NeoPop.State.success300))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)

                    if index < payments.count - 1 {
                        Rectangle()
                            .fill(Color.NeoPop.Black.c200)
                            .frame(height: 0.5)
                            .padding(.leading, 64)
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

    // MARK: - Mark paid

    private func markPaid(date: String, amount: Double?) async {
        isMarkingPaid = true
        do {
            let updated = try await APIClient.shared.markUtilityBillPaid(
                billId:      bill.id,
                paymentDate: date,
                paidAmount:  amount
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                bill = updated
            }
        } catch {
            // Silent — user can retry via the nav bar button
        }
        isMarkingPaid = false
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }

    private var dueDateColor: Color? {
        guard let iso = bill.dueDate else { return nil }
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let due = p.date(from: iso) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: due).day ?? 0
        if days < 0   { return Color(UIColor.NeoPop.State.error500) }   // overdue
        if days <= 5  { return Color(UIColor.NeoPop.State.error300) }   // due soon
        if days <= 10 { return Color(UIColor.NeoPop.State.warning300) }
        return nil
    }

    private func monthYear(_ iso: String?) -> String {
        guard let iso else { return "Bill" }
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let date = p.date(from: iso) else { return iso }
        let d = DateFormatter()
        d.dateFormat = "MMM yyyy"
        return d.string(from: date)
    }

    /// Nav bar heading: National Grid shows billing period range; Eversource shows bill date month.
    private var navHeading: String {
        let isNatGrid = bill.billerName.uppercased().contains("NATIONAL")
        if isNatGrid,
           let start = bill.billingPeriodStart,
           let end   = bill.billingPeriodEnd {
            let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd"; p.locale = Locale(identifier: "en_US_POSIX")
            let mon: (String) -> String = { iso in
                guard let date = p.date(from: iso) else { return iso }
                let d = DateFormatter(); d.dateFormat = "MMM yyyy"; return d.string(from: date)
            }
            let monNoYear: (String) -> String = { iso in
                guard let date = p.date(from: iso) else { return iso }
                let d = DateFormatter(); d.dateFormat = "MMM"; return d.string(from: date)
            }
            let sY = String(start.prefix(4)), eY = String(end.prefix(4))
            return sY == eY ? "\(monNoYear(start)) – \(mon(end))" : "\(mon(start)) – \(mon(end))"
        }
        return monthYear(bill.billDate ?? bill.dueDate)
    }

    private func formatDate(_ iso: String) -> String {
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let date = p.date(from: iso) else { return iso }
        let d = DateFormatter()
        d.dateStyle = .medium
        d.timeStyle = .none
        return d.string(from: date)
    }

    private func formatCurrency(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "$%.1fK", v / 1_000) }
        return String(format: "$%.2f", v)
    }
}

// MARK: - Bill Info Row

private struct BillInfoRow: View {
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

// MARK: - Mark Utility Paid Sheet

private struct MarkUtilityPaidSheet: View {
    let bill:      UtilityBillDTO
    let onConfirm: (String, Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var amountText   = ""

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.NeoPop.Black.c200)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Mark as Paid")
                .font(.ctTitle)
                .foregroundColor(.ctTextPrimary)
                .padding(.bottom, 24)

            VStack(spacing: 0) {
                // Date picker row
                HStack {
                    Label("Payment Date", systemImage: "calendar")
                        .font(.ctBody)
                        .foregroundColor(.ctTextPrimary)
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color(UIColor.NeoPop.State.success300))
                        .colorScheme(.dark)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.NeoPop.Black.c200)
                    .frame(height: 0.5)
                    .padding(.leading, 16)

                // Amount row
                HStack {
                    Label("Amount Paid", systemImage: "dollarsign.circle")
                        .font(.ctBody)
                        .foregroundColor(.ctTextPrimary)
                    Spacer()
                    TextField(bill.amountDue.map { String(format: "%.2f", $0) } ?? "Optional",
                              text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.ctBody)
                        .foregroundColor(.ctTextPrimary)
                        .frame(width: 120)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
            .padding(.horizontal, 20)

            Spacer()

            NeoPopFloatingButton(
                title:      "Confirm",
                shimmer:    false,
                faceColor:  UIColor.NeoPop.State.success300,
                labelColor: .white,
                showArrow:  false
            ) {
                let amount = Double(amountText.trimmingCharacters(in: .whitespaces))
                dismiss()
                onConfirm(dateString, amount)
            }
            .frame(height: 56)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .onAppear {
            // Pre-fill date with due date (capped at today) if available
            if let iso = bill.dueDate {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                if let d = f.date(from: iso) { selectedDate = min(d, Date()) }
            }
            // Pre-fill amount with the bill amount
            if let amount = bill.amountDue {
                amountText = String(format: "%.2f", amount)
            }
        }
    }
}
