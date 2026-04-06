import SwiftUI

// MARK: - Sheet container

struct AddCardView: View {
    @StateObject private var vm = AddCardViewModel()
    @Environment(\.dismiss) private var dismiss
    let onAdded: () -> Void

    var body: some View {
        ZStack {
            Color.ctBackground.ignoresSafeArea()
            content
        }
        .ctToast($vm.toast)
        .onChange(of: vm.shouldDismiss) { _, should in
            if should { onAdded(); dismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.step {
        case .entry:
            EntryScreen(vm: vm, onDismiss: { dismiss() })
                .transition(.opacity)
        case .lookingUp:
            StatusScreen(label: "Looking up card\u{2026}")
        case .picking(let issuer, let products):
            PickerScreen(vm: vm, issuerName: issuer, products: products)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .saving:
            StatusScreen(label: "Adding card\u{2026}")
        case .done:
            StatusScreen(label: "Done!")
        case .failed(let msg):
            FailureScreen(message: msg, onRetry: vm.retry)
        }
    }
}

// MARK: - Entry screen

private struct EntryScreen: View {
    @ObservedObject var vm: AddCardViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Spacer().frame(height: 36)
            numberField
            Spacer().frame(height: 24)
            nameField
            Spacer()
            continueButton
        }
    }

    // ── Nav ──────────────────────────────────────────────────────────────────

    private var navBar: some View {
        HStack {
            Text("Add New Card")
                .font(.ctTitle)
                .foregroundColor(.ctTextPrimary)
            Spacer()
            SynthIconButton(
                image: NeoPopIcons.closeUIImage?.withTintColor(.white, renderingMode: .alwaysOriginal),
                iconSize: 12,
                action: onDismiss
            )
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // ── Card number ───────────────────────────────────────────────────────────

    private var numberField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CARD NUMBER")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.horizontal, 20)

            NeoPopInputField(
                placeholder: "XXXX  XXXX  XXXX  XXXX",
                text: Binding(
                    get: { vm.formattedNumber },
                    set: { vm.rawNumber = String($0.filter(\.isNumber).prefix(16)) }
                ),
                keyboardType: .numberPad,
                font: .gilroy(.semiBold, size: 18),
                borderColor: vm.isCardNumberValid
                    ? UIColor.NeoPop.State.success300
                    : vm.rawNumber.filter(\.isNumber).count == 16
                        ? UIColor.NeoPop.State.error300
                        : .white
            )
            .frame(height: 56)
            .padding(.horizontal, 20)
        }
    }

    // ── Cardholder name ───────────────────────────────────────────────────────

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NAME ON CARD")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.horizontal, 20)

            NeoPopInputField(
                placeholder: "AS ON CARD",
                text: $vm.holderName,
                autocapitalization: .allCharacters,
                font: .gilroy(.medium, size: 16)
            )
            .frame(height: 56)
            .padding(.horizontal, 20)
        }
    }

    // ── Continue ─────────────────────────────────────────────────────────────

    private var continueButton: some View {
        NeoPopFloatingButton(
            title: "Continue",
            isEnabled: vm.canContinue,
            shimmer: false
        ) {
            Task { await vm.lookupAndFetch() }
        }
        .frame(height: 56)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - Picker screen

private struct PickerScreen: View {
    @ObservedObject var vm: AddCardViewModel
    let issuerName: String
    let products: [CardProductDTO]

    @State private var hintPlayed = false

    private var selected: CardProductDTO? {
        products.indices.contains(vm.selectedIndex) ? products[vm.selectedIndex] : nil
    }

    // How much of the adjacent cards peek in from each side
    private let peek: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Spacer().frame(height: 20)
            carousel
            Spacer().frame(height: 10)
            cardName
            Spacer().frame(height: 8)
            pageDots
            Spacer().frame(height: 28)
            limitSection
            Spacer().frame(height: 20)
            addButton
        }
    }

    // ── Nav ──────────────────────────────────────────────────────────────────

    private var navBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button — absolute top-left corner
            SynthIconButton(
                image: NeoPopIcons.arrowUIImage?.withTintColor(.white, renderingMode: .alwaysOriginal),
                iconSize: 16,
                action: vm.back
            )
            .frame(width: 44, height: 44)

            Spacer().frame(height: 10)

            Text("Which card is it?")
                .font(.ctTitle)
                .foregroundColor(.ctTextPrimary)

            Text(issuerName)
                .font(.ctCaption)
                .foregroundColor(.ctTextSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    // ── Horizontal carousel with peek ─────────────────────────────────────────

    // Two-way binding between vm.selectedIndex (Int) and ScrollView's id (Int?)
    private var scrollPosition: Binding<Int?> {
        Binding(
            get: { vm.selectedIndex },
            set: { if let v = $0 { vm.selectedIndex = v } }
        )
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(products.indices, id: \.self) { i in
                    CreditCardView(card: products[i].toCardModel())
                        .frame(width: cardWidth, height: cardHeight)
                        .id(i)
                        // Adjacent cards scale down slightly so you can see them
                        .scaleEffect(vm.selectedIndex == i ? 1.0 : 0.93)
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.selectedIndex)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: scrollPosition)
        .scrollTargetBehavior(.viewAligned)
        // peek padding reveals adjacent cards on both sides
        .contentMargins(.horizontal, peek)
        .frame(height: cardHeight + 8)
        .onAppear { playSwipeHint() }
    }

    // On first appear: briefly scroll to card 1 then snap back to show there are more cards
    private func playSwipeHint() {
        guard products.count > 1, !hintPlayed else { return }
        hintPlayed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { vm.selectedIndex = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { vm.selectedIndex = 0 }
            }
        }
    }

    // ── Card name label ───────────────────────────────────────────────────────

    private var cardName: some View {
        Text(selected?.productName ?? "")
            .font(.ctCaption)
            .foregroundColor(.ctTextPrimary)
            .animation(.easeInOut(duration: 0.2), value: vm.selectedIndex)
    }

    // ── Page dots ─────────────────────────────────────────────────────────────

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(products.indices, id: \.self) { i in
                let active = vm.selectedIndex == i
                Group {
                    if active {
                        // Active: NeoPop checkmark icon
                        NeoPopIcons.checkmark
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: 12, height: 10)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.selectedIndex)
            }
        }
    }

    // ── Credit limit ──────────────────────────────────────────────────────────

    private var limitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREDIT LIMIT")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.horizontal, 20)

            NeoPopInputField(
                placeholder: "0",
                text: $vm.limitText,
                keyboardType: .decimalPad,
                font: .gilroy(.semiBold, size: 18),
                prefix: "$"
            )
            .frame(height: 56)
            .padding(.horizontal, 20)
        }
    }

    // ── Add to Wallet ─────────────────────────────────────────────────────────

    private var addButton: some View {
        NeoPopFloatingButton(
            title: "Add to Wallet",
            shimmer: true
        ) {
            guard let product = selected else { return }
            Task { await vm.addCard(product: product) }
        }
        .frame(height: 56)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - Status screen

private struct StatusScreen: View {
    let label: String
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.4)
            Text(label)
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Failure screen

private struct FailureScreen: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.ctTextPrimary)
            Text("Something went wrong")
                .font(.ctHeadline)
                .foregroundColor(.ctTextPrimary)
            Text(message)
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again", action: onRetry)
                .font(.ctButtonLabel)
                .foregroundColor(.ctTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
