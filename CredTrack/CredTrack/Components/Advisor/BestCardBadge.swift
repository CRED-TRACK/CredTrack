import SwiftUI

/// Small pill badge that flags a row as the global best card for that category.
struct BestCardBadge: View {
    var label: String = "Best"

    var body: some View {
        Text(label)
            .font(.ctMicro)
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.NeoPop.NeoPaccha.c500)
            .clipShape(Capsule())
    }
}
