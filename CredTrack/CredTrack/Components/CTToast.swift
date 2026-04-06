import SwiftUI

// MARK: - Toast model

struct CTToastMessage: Equatable {
    enum Style { case error, warning, success }
    let text:  String
    let style: Style
}

// MARK: - Toast view

struct CTToast: View {
    let message: CTToastMessage

    private var accent: Color {
        switch message.style {
        case .error:   return Color(UIColor.NeoPop.State.error300)
        case .warning: return Color(UIColor.NeoPop.State.warning300)
        case .success: return Color(UIColor.NeoPop.State.success300)
        }
    }

    private var icon: String {
        switch message.style {
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accent)
                .font(.system(size: 18, weight: .semibold))

            Text(message.text)
                .font(.ctBody)
                .foregroundColor(.ctTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ctSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(accent.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
}

// MARK: - View modifier

struct CTToastModifier: ViewModifier {
    @Binding var message: CTToastMessage?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let msg = message {
                CTToast(message: msg)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .opacity
                        )
                    )
                    .padding(.bottom, 32)
                    .zIndex(999)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeOut(duration: 0.25)) { message = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func ctToast(_ message: Binding<CTToastMessage?>) -> some View {
        modifier(CTToastModifier(message: message))
    }
}
