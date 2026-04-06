import SwiftUI
import Synth

struct CardListView: View {
    @Binding var selectedTab: Int
    private let cards = CardModel.allDemoCards

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                // ─── Header ───────────────────────────────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Cards")
                            .font(.ctDisplay)
                            .foregroundColor(.ctTextPrimary)
                        Text("\(cards.count) \(cards.count == 1 ? "card" : "cards")")
                            .font(.ctCaption)
                            .foregroundColor(.ctTextSecondary)
                    }
                    Spacer()
                    AddNewButton()
                        .frame(width: 130, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // ─── Cards ────────────────────────────────────────────────
                ForEach(cards) { card in
                    PressableCard(card: card) { selectedTab = 3 }
                }
            }
            .padding(.bottom, 48)
        }
        .background(Color.ctSurface.ignoresSafeArea())
    }
}

// MARK: - Pressable card wrapper
//
// SwiftUI owns the press state (@GestureState) and scale animation.
// DragGesture(minimumDistance:0) starts instantly on touch-down and resets
// on release — giving us a reliable pressed/idle signal even inside ScrollView.
// The gradient swap is driven into UIKit via updateUIView(isPressed:).

private struct PressableCard: View {
    let card:   CardModel
    let onTap:  () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        CreditCardView(card: card, isPressed: isPressed)
            .frame(width: cardWidth, height: cardHeight)
            .frame(maxWidth: .infinity)
            // Subtle scale — gradient does the main work, scale adds physicality
            .scaleEffect(isPressed ? 0.985 : 1.0)
            .animation(
                isPressed
                    ? .easeIn(duration: 0.08)                           // snap down
                    : .spring(response: 0.50, dampingFraction: 0.60),  // bounce up
                value: isPressed
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    // isPressed = true the moment finger touches
                    .updating($isPressed) { _, state, _ in state = true }
                    // Only navigate when finger lifts with minimal movement (= tap)
                    .onEnded { val in
                        let d = val.translation
                        if abs(d.width) < 10 && abs(d.height) < 10 { onTap() }
                    }
            )
    }
}

// MARK: - Synth elevatedSoft "Add New" Button

private struct AddNewButton: UIViewRepresentable {

    func makeUIView(context: Context) -> UIButton {
        let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 130, height: 44))

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ]
        btn.applyNeuBtnStyle(
            type: .elevatedSoft,
            attributedTitle: NSAttributedString(string: "  Add new", attributes: attrs),
            image: UIImage(systemName: "plus")?
                .withTintColor(.white, renderingMode: .alwaysOriginal),
            imageDimension: 14
        )

        return btn
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
