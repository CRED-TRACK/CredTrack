import SwiftUI
import UIKit
import Combine

@MainActor
final class NotificationPreferencesViewModel: ObservableObject {
    @Published var isLoading       = false
    @Published var isSaving        = false
    @Published var linked          = false
    @Published var botUsername:      String?
    @Published var prefs           = TelegramPreferences(
        notifyStatements:   true,
        notifyTransactions: false,
        notifyPayments:     false,
        notifyUtilityBills: false
    )
    @Published var errorMessage:    String?
    @Published var pendingDeepLink: URL?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let s = try await APIClient.shared.fetchTelegramStatus()
            linked      = s.linked
            botUsername = s.botUsername
            prefs       = s.prefs
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startLink() async {
        do {
            let resp = try await APIClient.shared.createTelegramLinkToken()
            botUsername = resp.botUsername
            let deepLink   = URL(string: resp.deepLink)
            let httpsLink  = URL(string: resp.httpsLink)
            if let deepLink, UIApplication.shared.canOpenURL(deepLink) {
                pendingDeepLink = deepLink
            } else if let httpsLink {
                pendingDeepLink = httpsLink
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePrefs() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await APIClient.shared.updateTelegramPreferences(prefs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlink() async {
        do {
            try await APIClient.shared.unlinkTelegram()
            linked = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var vm = NotificationPreferencesViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Telegram")) {
                    if vm.linked {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                            Text("Linked to Telegram")
                            Spacer()
                        }
                        Button(role: .destructive) {
                            Task { await vm.unlink() }
                        } label: {
                            Text("Unlink")
                        }
                    } else {
                        Text("Get free notifications via Telegram. No Apple Developer account or push fees needed.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button {
                            Task { await vm.startLink() }
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Link Telegram")
                            }
                        }
                    }
                }

                Section(
                    header: Text("Notify me about"),
                    footer: Text(vm.linked
                                 ? "Choose which events send a Telegram message."
                                 : "Link Telegram first to enable notifications.")
                ) {
                    Toggle("New statement",       isOn: $vm.prefs.notifyStatements)
                    Toggle("New transaction",     isOn: $vm.prefs.notifyTransactions)
                    Toggle("Payment confirmation", isOn: $vm.prefs.notifyPayments)
                    Toggle("Utility bill received", isOn: $vm.prefs.notifyUtilityBills)
                }
                .disabled(!vm.linked || vm.isSaving)
                .onChange(of: vm.prefs) { _, _ in
                    Task { await vm.savePrefs() }
                }

                if vm.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Loading…").foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await vm.load() }
            .alert("Telegram", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .onChange(of: vm.pendingDeepLink) { _, url in
                guard let url else { return }
                UIApplication.shared.open(url) { _ in
                    Task { await vm.load() }
                }
                vm.pendingDeepLink = nil
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await vm.load() } }
            }
        }
    }
}
