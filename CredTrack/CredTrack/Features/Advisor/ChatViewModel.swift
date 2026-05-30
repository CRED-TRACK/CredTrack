import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var sending: Bool = false
    @Published var draft: String = ""

    init() {
        messages.append(ChatMessage(
            role: .assistant,
            text: "Hi! Ask me which card to use for any specific purchase — like \"Doordash gift card\" or \"$40 grocery run at Whole Foods\". I answer using your card terms and reward rules.")
        )
    }

    func send() async {
        let q = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !sending else { return }
        sending = true
        draft = ""
        messages.append(ChatMessage(role: .user, text: q))
        // Snapshot history excluding the latest user message we just sent (server reads `question` separately).
        let history = Array(messages.dropLast())

        do {
            let resp = try await APIClient.shared.sendChat(question: q, history: history)
            var assistant = ChatMessage(role: .assistant, text: resp.answer, sources: resp.sources)
            if resp.rateLimited == true { assistant.isError = true }
            messages.append(assistant)
        } catch {
            messages.append(ChatMessage(
                role: .assistant,
                text: "Couldn't reach the advisor (\(error.localizedDescription)). Try again shortly.",
                isError: true))
        }
        sending = false
    }
}
