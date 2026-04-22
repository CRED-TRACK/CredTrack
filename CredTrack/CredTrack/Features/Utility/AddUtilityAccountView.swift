import Foundation
import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
final class AddUtilityAccountViewModel: ObservableObject {

    enum Step: Equatable {
        case entry, saving, done, failed(String)
    }

    // Ordered list of supported billers — drives the picker carousel
    let billers: [(key: String, label: String)] = [
        ("EVERSOURCE",    "Eversource"),
        ("NATIONAL_GRID", "National Grid")
    ]

    @Published var step:           Step             = .entry
    @Published var selectedIndex:  Int              = 0
    @Published var lastFour:       String           = ""
    @Published var toast:          CTToastMessage?  = nil
    @Published var shouldDismiss:  Bool             = false

    var selectedBiller: String { billers[selectedIndex].key }

    var isLastFourValid: Bool {
        lastFour.filter(\.isNumber).count == 4
    }

    var canAdd: Bool { isLastFourValid }

    // MARK: Actions

    func add() async {
        guard canAdd else { return }
        step = .saving
        do {
            _ = try await APIClient.shared.addUtilityAccount(
                billerName:       selectedBiller,
                accountLastFour:  String(lastFour.filter(\.isNumber).prefix(4))
            )
            step = .done
            try? await Task.sleep(for: .seconds(0.8))
            shouldDismiss = true
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    func retry() { step = .entry }
}

// MARK: - Sheet container

struct AddUtilityAccountView: View {
    @StateObject private var vm = AddUtilityAccountViewModel()
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
            UtilityEntryScreen(vm: vm, onDismiss: { dismiss() })
                .transition(.opacity)
        case .saving:
            UtilityStatusScreen(label: "Adding account\u{2026}")
        case .done:
            UtilityStatusScreen(label: "Done!")
        case .failed(let msg):
            UtilityFailureScreen(message: msg, onRetry: vm.retry)
        }
    }
}

// MARK: - Entry screen

private struct UtilityEntryScreen: View {
    @ObservedObject var vm: AddUtilityAccountViewModel
    let onDismiss: () -> Void

    private let peek: CGFloat = 30

    // Two-way binding for the carousel scroll position
    private var scrollPosition: Binding<Int?> {
        Binding(
            get: { vm.selectedIndex },
            set: { if let v = $0 { vm.selectedIndex = v } }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Spacer().frame(height: 24)
            providerLabel
            Spacer().frame(height: 16)
            carousel
            Spacer().frame(height: 10)
            pageDots
            Spacer().frame(height: 28)
            lastFourSection
            Spacer()
            addButton
        }
    }

    // ── Nav ───────────────────────────────────────────────────────────────────

    private var navBar: some View {
        HStack {
            Text("Add Utility Account")
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

    // ── Section label ─────────────────────────────────────────────────────────

    private var providerLabel: some View {
        Text("SELECT PROVIDER")
            .font(.ctMicro)
            .foregroundColor(.ctTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
    }

    // ── Biller carousel — same peek/snap pattern as PickerScreen ─────────────

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(vm.billers.indices, id: \.self) { i in
                    ZStack(alignment: .topTrailing) {
                        UtilityCardView(billerName: vm.billers[i].key)
                            .frame(width: cardWidth, height: cardHeight)
                            .id(i)
                            .scaleEffect(vm.selectedIndex == i ? 1.0 : 0.93)
                            .animation(.spring(response: 0.3, dampingFraction: 0.75),
                                       value: vm.selectedIndex)

                        // Selected checkmark badge
                        if vm.selectedIndex == i {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(UIColor.NeoPop.State.success300))
                                .background(Circle().fill(Color.ctBackground).padding(3))
                                .padding(10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .onTapGesture { withAnimation { vm.selectedIndex = i } }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: scrollPosition)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, peek)
        .frame(height: cardHeight + 8)
    }

    // ── Page dots ─────────────────────────────────────────────────────────────

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(vm.billers.indices, id: \.self) { i in
                let active = vm.selectedIndex == i
                Group {
                    if active {
                        NeoPopIcons.checkmark
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: 12, height: 10)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.30))
                            .frame(width: 5, height: 5)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.selectedIndex)
            }
        }
    }

    // ── Account last four ─────────────────────────────────────────────────────

    private var lastFourSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCOUNT LAST FOUR DIGITS")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.horizontal, 20)

            NeoPopInputField(
                placeholder: "XXXX",
                text: Binding(
                    get: { vm.lastFour },
                    set: { vm.lastFour = String($0.filter(\.isNumber).prefix(4)) }
                ),
                keyboardType: .numberPad,
                font: .gilroy(.semiBold, size: 22),
                borderColor: vm.isLastFourValid
                    ? UIColor.NeoPop.State.success300
                    : vm.lastFour.filter(\.isNumber).count > 0
                        ? UIColor.NeoPop.State.error300
                        : .white
            )
            .frame(height: 56)
            .padding(.horizontal, 20)
        }
    }

    // ── Add Account button ────────────────────────────────────────────────────

    private var addButton: some View {
        NeoPopFloatingButton(
            title: "Add Account",
            isEnabled: vm.canAdd,
            shimmer: false
        ) {
            Task { await vm.add() }
        }
        .frame(height: 56)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - Status / Failure screens (local copies — AddCardView's are private)

private struct UtilityStatusScreen: View {
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

private struct UtilityFailureScreen: View {
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
