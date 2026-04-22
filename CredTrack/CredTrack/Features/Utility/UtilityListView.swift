import Foundation
import SwiftUI
import Synth

// MARK: - UtilityListView
// Tab-root view for the Utility tab.
// Shows all registered utility accounts as full-size cards.
// Tapping an account navigates to UtilityBillsView.

struct UtilityListView: View {

    @State private var accounts:           [UtilityAccountDTO] = []
    @State private var isLoading           = false
    @State private var showAddUtility      = false
    @State private var accountToDelete:    UtilityAccountDTO? = nil
    @State private var showDeleteAlert     = false
    @State private var isDeleting          = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .background(Color.ctSurface.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: UtilityAccountDTO.self) { account in
                UtilityBillsView(account: account) { _ in
                    Task { await load() }
                }
            }
        }
        .tint(.ctTextPrimary)
        .sheet(isPresented: $showAddUtility) {
            AddUtilityAccountView { Task { await load() } }
                .presentationBackground(Color.ctSurface)
        }
        .task { await load() }
        .alert("Remove Account?", isPresented: $showDeleteAlert, presenting: accountToDelete) { account in
            Button("Remove", role: .destructive) { deleteAccount(account) }
            Button("Cancel", role: .cancel) { accountToDelete = nil }
        } message: { account in
            let biller = account.billerName == "NATIONAL_GRID" ? "National Grid" : "Eversource"
            return Text("This will permanently delete the \(biller) account ending in \(account.accountLastFour) and all its bills and payments. This cannot be undone.")
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if accounts.isEmpty {
            emptyView
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    ForEach(accounts) { account in
                        PressableUtilityAccountCard(account: account)
                            .contextMenu {
                                Button(role: .destructive) {
                                    accountToDelete = account
                                    showDeleteAlert = true
                                } label: {
                                    Label("Remove Account", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Utility")
                    .font(.ctDisplay)
                    .foregroundColor(.ctTextPrimary)
                Text(accounts.count == 1
                     ? "1 account"
                     : "\(accounts.count) accounts")
                    .font(.ctCaption)
                    .foregroundColor(.ctTextSecondary)
            }
            Spacer()
            UtilityAddNewButton { showAddUtility = true }
                .frame(width: 130, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Utility")
                        .font(.ctDisplay)
                        .foregroundColor(.ctTextPrimary)
                    Text("No accounts added")
                        .font(.ctCaption)
                        .foregroundColor(.ctTextSecondary)
                }
                Spacer()
                UtilityAddNewButton { showAddUtility = true }
                    .frame(width: 130, height: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "bolt.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.ctTextSecondary)
                Text("No utility accounts yet")
                    .font(.ctHeadline)
                    .foregroundColor(.ctTextPrimary)
                Text("Tap \"Add new\" to track Eversource\nor National Grid bills.")
                    .font(.ctBody)
                    .foregroundColor(.ctTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.ctTextPrimary)
                .scaleEffect(1.4)
            Text("Loading accounts…")
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Delete

    private func deleteAccount(_ account: UtilityAccountDTO) {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            try? await APIClient.shared.deleteUtilityAccount(id: account.id)
            isDeleting      = false
            accountToDelete = nil
            await load()
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        accounts  = (try? await APIClient.shared.fetchUtilityAccounts()) ?? []
        isLoading = false
    }
}

// MARK: - Pressable card (same press style as Cards tab)

private struct PressableUtilityAccountCard: View {
    let account: UtilityAccountDTO
    @State private var isPressed = false

    var body: some View {
        NavigationLink(value: account) {
            UtilityCardView(billerName: account.billerName, lastFour: account.accountLastFour)
                .frame(width: cardWidth, height: cardHeight)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(UtilityCardPressStyle(isPressed: $isPressed))
    }
}

private struct UtilityCardPressStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(
                configuration.isPressed
                    ? .easeIn(duration: 0.08)
                    : .spring(response: 0.50, dampingFraction: 0.60),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}

// MARK: - "Add new" button (Synth elevatedSoft — matches Cards tab)

private struct UtilityAddNewButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> UIButton {
        let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 130, height: 44))
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.gilroy(.semiBold, size: 15)
        ]
        btn.applyNeuBtnStyle(
            type: .elevatedSoft,
            attributedTitle: NSAttributedString(string: "  Add new", attributes: attrs),
            image: UIImage(systemName: "plus")?
                .withTintColor(.white, renderingMode: .alwaysOriginal),
            imageDimension: 14
        )
        btn.addTarget(context.coordinator,
                      action: #selector(Coordinator.tapped),
                      for: .touchUpInside)
        return btn
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
