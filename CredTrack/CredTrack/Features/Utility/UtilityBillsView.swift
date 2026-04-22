import Foundation
import SwiftUI
import UIKit

// MARK: - UtilityBillsView
// Shows all bills for a single utility account.
// Navigation pattern mirrors StatementsListView.

struct UtilityBillsView: View {
    let account: UtilityAccountDTO
    var onDeleted: ((UtilityAccountDTO) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var bills:          [UtilityBillDTO] = []
    @State private var isLoading       = false
    @State private var showRemoveAlert = false
    @State private var isRemoving      = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            navBar
            cardPreview
            content
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
        .alert("Remove Account?", isPresented: $showRemoveAlert) {
            Button("Remove", role: .destructive) { removeAccount() }
            Button("Cancel", role: .cancel) { }
        } message: {
            let biller = account.billerName == "NATIONAL_GRID" ? "National Grid" : "Eversource"
            return Text("This will permanently delete the \(biller) account ending in \(account.accountLastFour) and all its bills and payments. This cannot be undone.")
        }
    }

    // ── Nav bar ───────────────────────────────────────────────────────────────

    private var navBar: some View {
        HStack {
            CTBackButton { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text(BillerStyle(billerName: account.billerName).displayName)
                    .font(.ctTitle)
                    .foregroundColor(.ctTextPrimary)
                Text("Bills")
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

    // ── Card preview ──────────────────────────────────────────────────────────

    private var cardPreview: some View {
        UtilityCardView(billerName: account.billerName, lastFour: account.accountLastFour)
            .frame(width: cardWidth, height: cardHeight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }

    // ── Content ───────────────────────────────────────────────────────────────

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            ProgressView()
                .tint(.ctTextSecondary)
            Spacer()
            removeAccountSection
        } else if bills.isEmpty {
            Spacer()
            Text("No bills found yet")
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
            Text("Bills are fetched automatically from Gmail.")
                .font(.ctCaption)
                .foregroundColor(.ctTextSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 6)
            Spacer()
            removeAccountSection
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(bills.enumerated()), id: \.element.id) { index, bill in
                        NavigationLink(destination: UtilityBillDetailView(bill: bill, account: account)) {
                            UtilityBillRow(bill: bill)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < bills.count - 1 {
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
                .padding(.vertical, 4)

                removeAccountSection
            }
        }
    }

    private var removeAccountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DANGER ZONE")
                .font(.ctMicro)
                .foregroundColor(Color(UIColor.NeoPop.State.error300))
                .padding(.leading, 4)
                .padding(.horizontal, 20)

            NeoPopElevatedButton(
                title:          isRemoving ? "Removing…" : "Remove Account",
                faceColor:      UIColor.NeoPop.State.error500,
                labelColor:     .white,
                superViewColor: .popDeepBlack,
                fontSize:       15
            ) {
                showRemoveAlert = true
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .padding(.horizontal, 20)
            .disabled(isRemoving)
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private func removeAccount() {
        guard !isRemoving else { return }
        isRemoving = true
        Task {
            try? await APIClient.shared.deleteUtilityAccount(id: account.id)
            onDeleted?(account)
            dismiss()
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        bills = (try? await APIClient.shared.fetchUtilityBills(
            billerName: account.billerName,
            accountLastFour: account.accountLastFour
        )) ?? []
        isLoading = false
    }
}

// MARK: - Bill row

private struct UtilityBillRow: View {
    let bill: UtilityBillDTO

    private func fmt(_ iso: String?) -> String {
        guard let iso else { return "—" }
        let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd"; p.locale = .init(identifier: "en_US_POSIX")
        guard let date = p.date(from: iso) else { return iso }
        let d = DateFormatter(); d.dateStyle = .medium; d.timeStyle = .none
        return d.string(from: date)
    }

    private func monthYear(_ iso: String?) -> String {
        guard let iso else { return "—" }
        let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd"; p.locale = .init(identifier: "en_US_POSIX")
        guard let date = p.date(from: iso) else { return iso }
        let d = DateFormatter(); d.dateFormat = "MMM yyyy"
        return d.string(from: date)
    }

    /// Row heading: National Grid shows billing period range; Eversource shows bill date month.
    private func rowHeading(for bill: UtilityBillDTO) -> String {
        let isNatGrid = bill.billerName.uppercased().contains("NATIONAL")
        if isNatGrid,
           let start = bill.billingPeriodStart,
           let end   = bill.billingPeriodEnd {
            // e.g. "Jan – Feb 2026" or "Dec 2025 – Jan 2026"
            let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd"; p.locale = .init(identifier: "en_US_POSIX")
            let fmtMon: (String) -> String = { iso in
                guard let date = p.date(from: iso) else { return iso }
                let d = DateFormatter(); d.dateFormat = "MMM yyyy"
                return d.string(from: date)
            }
            let fmtMonNoYear: (String) -> String = { iso in
                guard let date = p.date(from: iso) else { return iso }
                let d = DateFormatter(); d.dateFormat = "MMM"
                return d.string(from: date)
            }
            // If same year: "Jan – Feb 2026"; different year: "Dec 2025 – Jan 2026"
            let startYear = String(start.prefix(4))
            let endYear   = String(end.prefix(4))
            if startYear == endYear {
                return "\(fmtMonNoYear(start)) – \(fmtMon(end))"
            } else {
                return "\(fmtMon(start)) – \(fmtMon(end))"
            }
        }
        // Eversource (and fallback): billDate → dueDate
        return monthYear(bill.billDate ?? bill.dueDate)
    }

    private func currency(_ v: Double?) -> String {
        guard let v else { return "—" }
        if v >= 1_000 { return String(format: "$%.0f", v) }
        return String(format: "$%.2f", v)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.ctTextPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.NeoPop.Black.c200))

            // Bill details
            VStack(alignment: .leading, spacing: 4) {
                Text(rowHeading(for: bill))
                    .font(.ctBody)
                    .foregroundColor(.ctTextPrimary)

                HStack(spacing: 6) {
                    if let due = bill.dueDate {
                        Label(fmt(due), systemImage: "calendar")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                    if let start = bill.billingPeriodStart, let end = bill.billingPeriodEnd {
                        Text("·")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                        Text("\(fmt(start)) – \(fmt(end))")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                }
            }

            Spacer()

            // Amount + paid badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(currency(bill.amountDue))
                    .font(.system(.body, design: .default).weight(.semibold))
                    .foregroundColor(.ctTextPrimary)

                if bill.isPaid == true {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(UIColor.NeoPop.State.success300))
                } else if let paid = bill.totalPaid, paid > 0 {
                    Text("Partial \(currency(paid))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(UIColor.NeoPop.State.warning300))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
