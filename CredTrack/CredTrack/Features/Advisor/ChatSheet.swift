import SwiftUI

/// Real chat advisor (Phase 2). Replaces the placeholder sheet.
struct ChatSheet: View {
    @StateObject private var vm = ChatViewModel()
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ctBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    messagesList
                    composer
                }
            }
            .navigationTitle("Advisor Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onClose() }
                        .foregroundColor(.ctTextSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(vm.messages) { msg in
                        ChatMessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if vm.sending {
                        HStack(spacing: 8) {
                            ProgressView().tint(.ctTextSecondary)
                            Text("Thinking…")
                                .font(.ctCaption)
                                .foregroundColor(.ctTextSecondary)
                        }
                        .padding(.leading, 12)
                        .id("typing")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().background(Color.ctSurface)
            HStack(spacing: 8) {
                TextField("Ask about a purchase…", text: $vm.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.ctSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.ctTextPrimary)
                    .font(.ctBody)
                    .submitLabel(.send)
                    .onSubmit { Task { await vm.send() } }

                Button {
                    Task { await vm.send() }
                } label: {
                    Image(systemName: vm.sending ? "hourglass" : "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.sending
                                         ? .ctTextSecondary
                                         : .NeoPop.NeoPaccha.c500)
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.sending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.ctBackground)
        }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.ctBody)
                    .foregroundColor(message.isError ? .orange : .ctTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !message.sources.isEmpty {
                    sourcesList
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.role == .user
                        ? Color.NeoPop.NeoPaccha.c500.opacity(0.18)
                        : Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var sourcesList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(message.sources.enumerated()), id: \.element.id) { idx, s in
                VStack(alignment: .leading, spacing: 2) {
                    Text("[S\(idx + 1)] \(s.cardLabel)")
                        .font(.ctMicro)
                        .foregroundColor(.NeoPop.NeoPaccha.c500)
                    Text(s.snippet)
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                        .lineLimit(3)
                }
                .padding(.top, 4)
            }
        }
    }
}
