import SwiftUI

/// Vertical list of categories with display name + common-merchants subtitle.
/// Used both for the top filter picker and the BofA 3% choice.
struct CategoryPickerSheet: View {
    let title: String
    let categories: [AdvisorCategoryDTO]
    let selected: String?
    let onSelect: (AdvisorCategoryDTO) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(categories) { cat in
                        Button {
                            onSelect(cat)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: cat.iconHint)
                                    .font(.system(size: 18))
                                    .frame(width: 28)
                                    .foregroundColor(.ctTextPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.displayName)
                                        .font(.ctTitle)
                                        .foregroundColor(.ctTextPrimary)
                                    if !cat.commonMerchants.isEmpty {
                                        Text(cat.commonMerchants.prefix(3).joined(separator: ", "))
                                            .font(.ctCaption)
                                            .foregroundColor(.ctTextSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if selected == cat.code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.NeoPop.NeoPaccha.c500)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(Color.ctSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .background(Color.ctBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.ctTextPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
