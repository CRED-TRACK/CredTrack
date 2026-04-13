import SwiftUI

struct StatementsListView: View {
    let card: UserCardDTO

    @Environment(\.dismiss) private var dismiss

    @State private var statements:   [CardStatementDTO] = []
    @State private var isLoading     = false
    @State private var isLoadingMore = false
    @State private var currentPage   = 0
    @State private var hasMore       = true

    private let pageSize = 20

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // ── Nav bar ──────────────────────────────────────────────────────────
            HStack {
                CTBackButton { dismiss() }
                Spacer()
                VStack(spacing: 2) {
                    Text(card.nickname ?? card.productName)
                        .font(.ctTitle)
                        .foregroundColor(.ctTextPrimary)
                    Text("Statements")
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                }
                Spacer()
                // Balance spacer so title stays centred
                CTBackButton { dismiss() }
                    .opacity(0)
                    .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // ── Content ──────────────────────────────────────────────────────────
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.ctTextSecondary)
                Spacer()
            } else if statements.isEmpty {
                Spacer()
                Text("No statements yet")
                    .font(.ctBody)
                    .foregroundColor(.ctTextSecondary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(statements.enumerated()), id: \.element.id) { index, stmt in
                            StatementDetailRow(statement: stmt)

                            if index < statements.count - 1 {
                                Rectangle()
                                    .fill(Color.NeoPop.Black.c200)
                                    .frame(height: 0.5)
                                    .padding(.leading, 64)
                            }
                        }

                        if hasMore {
                            HStack {
                                Spacer()
                                if isLoadingMore {
                                    ProgressView()
                                        .tint(.ctTextSecondary)
                                } else {
                                    Button("Load more") {
                                        Task { await loadMore() }
                                    }
                                    .font(.ctBody)
                                    .foregroundColor(.ctTextSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 20)
                            .onAppear {
                                Task { await loadMore() }
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
                    .padding(.vertical, 16)
                }
            }
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await loadInitial() }
    }

    // MARK: - Load helpers

    private func loadInitial() async {
        isLoading   = true
        currentPage = 0
        hasMore     = true
        statements  = []
        await fetchPage(0)
        isLoading = false
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        await fetchPage(currentPage)
        isLoadingMore = false
    }

    private func fetchPage(_ page: Int) async {
        guard let result = try? await APIClient.shared.fetchStatements(
            cardId: card.id, page: page, size: pageSize
        ) else { return }

        statements  += result.content
        currentPage  = page + 1
        hasMore      = statements.count < result.totalElements
    }
}

// MARK: - Statement Detail Row

private struct StatementDetailRow: View {
    let statement: CardStatementDTO

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

    private func fmt(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }

    private func currency(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "$%.1fK", v / 1_000) }
        return String(format: "$%.0f", v)
    }

    private var hasActions: Bool {
        statement.viewStatementUrl != nil || statement.makePaymentUrl != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Main row ──────────────────────────────────────────────────────
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.ctTextPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.NeoPop.Black.c200))

                VStack(alignment: .leading, spacing: 4) {
                    Text(monthYear)
                        .font(.ctBody)
                        .foregroundColor(.ctTextPrimary)

                    HStack(spacing: 6) {
                        if let dd = statement.dueDate {
                            Label(fmt(dd), systemImage: "calendar")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                        }
                        if let md = statement.minimumDue {
                            Text("·")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                            Text("Min \(currency(md))")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                        }
                    }
                }

                Spacer()

                if let balance = statement.statementBalance {
                    Text(currency(balance))
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundColor(.ctTextPrimary)
                }
            }

            // ── Action buttons ────────────────────────────────────────────────
            if hasActions {
                HStack(spacing: 10) {
                    if let urlStr = statement.viewStatementUrl, let link = URL(string: urlStr) {
                        Link(destination: link) {
                            Label("View Statement", systemImage: "doc.text")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.NeoPop.Black.c200)
                                        .overlay(Capsule().strokeBorder(Color.NeoPop.Black.c100.opacity(0.4), lineWidth: 1))
                                )
                        }
                    }
                    if let urlStr = statement.makePaymentUrl, let link = URL(string: urlStr) {
                        Link(destination: link) {
                            Label("Pay Now", systemImage: "creditcard.fill")
                                .font(.ctMicro)
                                .foregroundColor(Color(UIColor.NeoPop.State.success300))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(UIColor.NeoPop.State.success300).opacity(0.12))
                                        .overlay(Capsule().strokeBorder(Color(UIColor.NeoPop.State.success300).opacity(0.35), lineWidth: 1))
                                )
                        }
                    }
                }
                .padding(.leading, 48) // align with text, past the icon
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
