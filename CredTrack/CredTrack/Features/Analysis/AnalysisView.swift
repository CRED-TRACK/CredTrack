import SwiftUI

struct AnalysisView: View {
    @State private var segment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                segmentPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Divider()
                    .background(Color.NeoPop.Black.c200)

                if segment == 0 {
                    CardSpendingAnalysisView()
                } else {
                    UtilityBillAnalysisView()
                }
            }
            .background(Color.ctBackground.ignoresSafeArea())
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(.ctTextPrimary)
    }

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(["Credit Cards", "Utilities"], id: \.self) { label in
                let idx = label == "Credit Cards" ? 0 : 1
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { segment = idx }
                } label: {
                    Text(label)
                        .font(.ctBodyMedium)
                        .foregroundColor(segment == idx ? .ctTextPrimary : .ctTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            segment == idx
                                ? Color.NeoPop.Black.c200
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .background(Color.NeoPop.Black.c300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
