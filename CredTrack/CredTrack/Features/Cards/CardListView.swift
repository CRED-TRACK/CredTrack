import SwiftUI
import Synth

struct CardListView: View {
    @Binding var selectedTab: Int
    @StateObject private var vm = UserCardsViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                loadingView
            case .loaded(let cards):
                cards.isEmpty ? AnyView(emptyView) : AnyView(cardScroll(cards: cards))
            case .failed(let msg):
                errorView(message: msg)
            }
        }
        .background(Color.ctSurface.ignoresSafeArea())
        .task { await vm.load() }
    }

    // MARK: - Card scroll

    private func cardScroll(cards: [CardModel]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header(count: cards.count)
                ForEach(cards) { card in
                    PressableCard(card: card) { selectedTab = 3 }
                }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 0) {
            header(count: 0)
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "creditcard")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.ctTextSecondary)
                Text("No cards yet")
                    .font(.ctHeadline)
                    .foregroundColor(.ctTextPrimary)
                Text("Tap \"Add new\" to add your first card.")
                    .font(.ctBody)
                    .foregroundColor(.ctTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    // MARK: - Shared header

    private func header(count: Int) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Cards")
                    .font(.ctDisplay)
                    .foregroundColor(.ctTextPrimary)
                Text(count == 0 ? "No cards added" : "\(count) \(count == 1 ? "card" : "cards")")
                    .font(.ctCaption)
                    .foregroundColor(.ctTextSecondary)
            }
            Spacer()
            AddNewButton()
                .frame(width: 130, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.ctGold)
                .scaleEffect(1.4)
            Text("Loading cards…")
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.ctGold)
            Text("Couldn't load cards")
                .font(.ctHeadline)
                .foregroundColor(.ctTextPrimary)
            Text(message)
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try again") { vm.reload() }
                .font(.ctButtonLabel)
                .foregroundColor(.ctGold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pressable card wrapper

private struct PressableCard: View {
    let card:  CardModel
    let onTap: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        CreditCardView(card: card, isPressed: isPressed)
            .frame(width: cardWidth, height: cardHeight)
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.985 : 1.0)
            .animation(
                isPressed
                    ? .easeIn(duration: 0.08)
                    : .spring(response: 0.50, dampingFraction: 0.60),
                value: isPressed
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
                    .onEnded { val in
                        let d = val.translation
                        if abs(d.width) < 10 && abs(d.height) < 10 { onTap() }
                    }
            )
    }
}

// MARK: - Synth elevatedSoft "Add New" button

private struct AddNewButton: UIViewRepresentable {

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
        return btn
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
