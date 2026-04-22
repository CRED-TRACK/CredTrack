import SwiftUI
import Synth

struct CardListView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var gmailManager: GmailConnectionManager
    @StateObject private var vm = UserCardsViewModel()
    @State private var showAddCard      = false
    @State private var showGmailPopup   = false
    @State private var cardToDelete:    UserCardDTO? = nil
    @State private var showDeleteAlert  = false

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
        .navigationBarHidden(true)
        .navigationDestination(for: UserCardDTO.self) { card in
            CardDetailView(card: card) { deleted in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    vm.removeCard(deleted)
                }
            }
        }
        .task { await vm.load() }
        .task(id: gmailManager.isConnected) {
            if !gmailManager.isConnected && !gmailManager.isChecking {
                try? await Task.sleep(for: .seconds(0.6))
                showGmailPopup = true
            }
        }
        .sheet(isPresented: $showGmailPopup) {
            GmailConnectSheet(manager: gmailManager, isPresented: $showGmailPopup)
                .presentationDetents([.height(280)])
                .presentationBackground(Color.ctSurface)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView { vm.reload() }
                .presentationBackground(Color.ctSurface)
        }
        .alert("Remove Card?", isPresented: $showDeleteAlert, presenting: cardToDelete) { card in
            Button("Remove", role: .destructive) { deleteCard(card) }
            Button("Cancel", role: .cancel) { cardToDelete = nil }
        } message: { card in
            Text("This will permanently delete \(card.nickname ?? card.productName) and all its statements, payments, and transactions. This cannot be undone.")
        }
    }

    // MARK: - Delete

    private func deleteCard(_ card: UserCardDTO) {
        cardToDelete = nil
        withAnimation(
            .spring(response: 0.42, dampingFraction: 0.78)
        ) {
            vm.removeCard(card)
        }
    }

    // MARK: - Card scroll

    private func cardScroll(cards: [UserCardDTO]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header(count: cards.count)
                if !gmailManager.isConnected {
                    GmailConnectBanner(manager: gmailManager)
                        .padding(.horizontal, 24)
                }
                ForEach(cards, id: \.id) { dto in
                    PressableCard(dto: dto)
                        .contextMenu {
                            Button(role: .destructive) {
                                cardToDelete   = dto
                                showDeleteAlert = true
                            } label: {
                                Label("Remove Card", systemImage: "trash")
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal:   .opacity.combined(with: .scale(scale: 0.82))
                            )
                        )
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

    // MARK: - Header

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
            AddNewButton { showAddCard = true }
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
                .tint(.ctTextPrimary)
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
                .foregroundColor(.ctTextSecondary)
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
                .foregroundColor(.ctTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pressable card wrapper
// NavigationLink(value:) provides the navigation push; CardPressStyle drives
// the gradient press animation on the underlying CreditCardView.

private struct PressableCard: View {
    let dto: UserCardDTO
    @State private var isPressed = false

    var body: some View {
        NavigationLink(value: dto) {
            CreditCardView(card: dto.toCardModel(), isPressed: isPressed)
                .frame(width: cardWidth, height: cardHeight)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CardPressStyle(isPressed: $isPressed))
    }
}

// ButtonStyle yields to the ScrollView on vertical drags — DragGesture(minimumDistance: 0)
// blocks scrolling because it wins the gesture arena before the scroll view can claim it.
private struct CardPressStyle: ButtonStyle {
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

// MARK: - Gmail Connect Banner (inline, persistent)

private struct GmailConnectBanner: View {
    @ObservedObject var manager: GmailConnectionManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 18))
                .foregroundColor(.ctGold)

            VStack(alignment: .leading, spacing: 2) {
                Text("Connect Gmail")
                    .font(.ctBody)
                    .foregroundColor(.ctTextPrimary)
                Text("Auto-import your bank transactions")
                    .font(.ctCaption)
                    .foregroundColor(.ctTextSecondary)
            }

            Spacer()

            Button {
                manager.startOAuth()
            } label: {
                if manager.isConnecting {
                    ProgressView().tint(.ctGold).scaleEffect(0.8)
                } else {
                    Text("Connect")
                        .font(.ctMicro)
                        .foregroundColor(.ctGold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.ctGold.opacity(0.10))
                                .overlay(Capsule().strokeBorder(Color.ctGold.opacity(0.40), lineWidth: 1))
                        )
                }
            }
            .disabled(manager.isConnecting)
        }
        .padding(14)
        .background(Color.ctSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.ctGold.opacity(0.20), lineWidth: 1)
        )
    }
}

// MARK: - Gmail Connect Sheet (popup shown once per session)

private struct GmailConnectSheet: View {
    @ObservedObject var manager: GmailConnectionManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.ctGold)

            Spacer().frame(height: 16)

            Text("Connect Gmail")
                .font(.ctHeadline)
                .foregroundColor(.ctTextPrimary)

            Spacer().frame(height: 8)

            Text("We need access to your Gmail inbox to automatically detect and import your credit card transactions from bank notification emails.")
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 28)

            HStack(spacing: 12) {
                Button("Not Now") {
                    isPresented = false
                }
                .font(.ctButtonLabel)
                .foregroundColor(.ctTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.NeoPop.Black.c200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    isPresented = false
                    manager.startOAuth()
                } label: {
                    if manager.isConnecting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Connect Gmail")
                            .font(.ctButtonLabel)
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.ctGold)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(manager.isConnecting)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)
        }
    }
}

// MARK: - Synth elevatedSoft "Add New" button

private struct AddNewButton: UIViewRepresentable {
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
