import SwiftUI

/// First-time prompt + later edit screen for the BofA Customized Cash 3% category.
struct BofaCategoryChoiceSheet: View {
    let userCardId: Int
    let currentChoice: String?
    let onSave: (String) async throws -> Void
    @Environment(\.dismiss) private var dismiss

    private let options: [(code: String, label: String, icon: String)] = [
        ("GAS_STATIONS",       "Gas",            "fuelpump.fill"),
        ("ONLINE_RETAIL",      "Online Shopping", "bag.fill"),
        ("DINING_RESTAURANTS", "Dining",         "fork.knife"),
        ("TRAVEL_GENERAL",     "Travel",         "airplane"),
        ("DRUGSTORES",         "Drug Stores",    "cross.case.fill"),
        ("HOME_IMPROVEMENT",   "Home Improvement", "hammer.fill")
    ]

    @State private var selected: String?
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Where do you spend most? You earn 3% on the category you pick. You can change it once per month at BofA.")
                        .font(.ctBody)
                        .foregroundColor(.ctTextSecondary)
                        .padding(.horizontal)

                    LazyVStack(spacing: 10) {
                        ForEach(options, id: \.code) { opt in
                            Button {
                                selected = opt.code
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: opt.icon)
                                        .font(.system(size: 18))
                                        .frame(width: 28)
                                        .foregroundColor(.ctTextPrimary)
                                    Text(opt.label)
                                        .font(.ctTitle)
                                        .foregroundColor(.ctTextPrimary)
                                    Spacer()
                                    if selected == opt.code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.NeoPop.NeoPaccha.c500)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(Color.ctSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let err = errorMessage {
                        Text(err)
                            .font(.ctCaption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    SynthButton(title: saving ? "Saving…" : "Save choice") {
                        save()
                    }
                    .frame(height: 56)
                    .padding(.horizontal)
                    .opacity(selected == nil || saving ? 0.5 : 1.0)
                    .disabled(selected == nil || saving)
                }
                .padding(.vertical, 12)
            }
            .background(Color.ctBackground.ignoresSafeArea())
            .navigationTitle("BofA 3% Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.ctTextSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if selected == nil { selected = currentChoice } }
    }

    private func save() {
        guard let code = selected, !saving else { return }
        saving = true
        errorMessage = nil
        Task {
            do {
                try await onSave(code)
                await MainActor.run {
                    saving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    saving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
