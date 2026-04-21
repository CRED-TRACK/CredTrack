import SwiftUI

struct TransactionsListView: View {
    let card: UserCardDTO

    @Environment(\.dismiss) private var dismiss

    @State private var transactions:  [TransactionDTO] = []
    @State private var total:         Int  = 0
    @State private var page:          Int  = 0
    @State private var isLoading      = false
    @State private var hasMore        = true
    @State private var errorMessage:  String? = nil

    private let pageSize = 20

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // ── Nav bar ──────────────────────────────────────────────────────
            HStack {
                CTBackButton { dismiss() }
                Spacer()
                VStack(spacing: 2) {
                    Text("Transactions")
                        .font(.ctHeadline)
                        .foregroundColor(.ctTextPrimary)
                    Text(card.nickname ?? card.productName)
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                }
                Spacer()
                // Balance spacer for centering
                CTBackButton { }
                    .opacity(0)
                    .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if isLoading && transactions.isEmpty {
                Spacer()
                ProgressView().tint(.ctTextSecondary)
                Spacer()
            } else if let err = errorMessage {
                Spacer()
                Text("Error: \(err)")
                    .font(.ctMicro)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                Spacer()
            } else if transactions.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await loadPage(reset: true) }
    }

    // MARK: - Transaction list

    private var transactionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Header count
                HStack {
                    Text("\(total) transaction\(total == 1 ? "" : "s")")
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                // Grouped by month
                ForEach(groupedByMonth, id: \.0) { month, items in
                    monthSection(month: month, items: items)
                }

                // Load more
                if hasMore {
                    Button {
                        Task { await loadPage(reset: false) }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.ctTextSecondary)
                            }
                            Text(isLoading ? "Loading…" : "Load more")
                                .font(.ctBody)
                                .foregroundColor(.ctTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Month section

    @ViewBuilder
    private func monthSection(month: String, items: [TransactionDTO]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(month)
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 4)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, tx in
                    TransactionRow(tx: tx)
                    if idx < items.count - 1 {
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 44))
                .foregroundColor(.ctTextSecondary)
            Text("No transactions yet")
                .font(.ctHeadline)
                .foregroundColor(.ctTextPrimary)
            Text("Transaction alerts from your bank\nwill appear here once synced.")
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Data

    private func loadPage(reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        if reset { page = 0; hasMore = true; errorMessage = nil }
        do {
            let result = try await APIClient.shared.fetchTransactions(
                cardId: card.id, page: page, size: pageSize)
            if reset { transactions = result.content }
            else      { transactions += result.content }
            total   = result.totalElements
            hasMore = transactions.count < total
            page   += 1
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Groups transactions by "MMM yyyy" label, preserving order
    private var groupedByMonth: [(String, [TransactionDTO])] {
        var groups: [(String, [TransactionDTO])] = []
        var seen: [String: Int] = [:]
        for tx in transactions {
            let key = monthLabel(tx.transactionDate)
            if let idx = seen[key] {
                groups[idx].1.append(tx)
            } else {
                seen[key] = groups.count
                groups.append((key, [tx]))
            }
        }
        return groups
    }

    private func monthLabel(_ iso: String?) -> String {
        guard let iso else { return "Unknown" }
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let d = p.date(from: iso) else { return "Unknown" }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: d)
    }
}

// MARK: - Transaction Row

private struct TransactionRow: View {
    let tx: TransactionDTO

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            Image(systemName: categoryIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.ctTextPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.NeoPop.Black.c200))

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchantName ?? "Unknown Merchant")
                    .font(.ctBody)
                    .foregroundColor(.ctTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let cat = tx.merchantCategory {
                        Text(cat.capitalized)
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                    if let date = formattedDate {
                        Text(tx.merchantCategory != nil ? "· \(date)" : date)
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let amount = tx.amount {
                    Text("\(isCredit ? "+" : "-")\(formatCurrency(amount))")
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundColor(isCredit
                            ? Color(UIColor.NeoPop.State.success300)
                            : .ctTextPrimary)
                }
                if let status = tx.status, status != "PENDING" {
                    Text(status.capitalized)
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var isCredit: Bool { tx.transactionType == "CREDIT" }

    private var formattedDate: String? {
        guard let iso = tx.transactionDate else { return nil }
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let d = p.date(from: iso) else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    private func formatCurrency(_ v: Double) -> String {
        if v >= 1_000 { return String(format: "$%.0f", v) }
        return String(format: "$%.2f", v)
    }

    private var categoryIcon: String {
        switch tx.merchantCategory?.lowercased() {
        case "dining", "restaurants", "food": return "fork.knife"
        case "travel", "airlines":            return "airplane"
        case "grocery", "groceries":          return "cart.fill"
        case "gas", "fuel":                   return "fuelpump.fill"
        case "entertainment":                 return "tv.fill"
        case "shopping", "retail":            return "bag.fill"
        case "health", "medical":             return "heart.fill"
        case "utilities":                     return "bolt.fill"
        default:                              return "creditcard.fill"
        }
    }
}
