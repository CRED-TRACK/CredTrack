import Foundation
import FirebaseAuth

// MARK: - Server response shapes

struct ChatResponseDTO: Decodable {
    let answer: String
    let sources: [ChatSourceDTO]
    let rateLimited: Bool?
}

struct ChatSourceDTO: Decodable, Identifiable, Hashable {
    var id: Int { chunkId }
    let chunkId: Int
    let documentId: Int
    let cardProductId: Int
    let cardLabel: String
    let snippet: String
    let similarity: Double?
}

private struct ChatRequestDTO: Encodable {
    let question: String
    let history: [ChatTurnDTO]

    struct ChatTurnDTO: Encodable {
        let role: String
        let content: String
    }
}

// MARK: - Client-side model

struct ChatMessage: Identifiable, Hashable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
    var sources: [ChatSourceDTO] = []
    var isError: Bool = false
}

// MARK: - APIClient extension

extension APIClient {
    func sendChat(question: String,
                  history: [ChatMessage]) async throws -> ChatResponseDTO {
        let token = try await chatCurrentToken()
        let payload = ChatRequestDTO(
            question: question,
            history: history.suffix(8).map { ChatRequestDTO.ChatTurnDTO(
                role: $0.role == .user ? "user" : "assistant",
                content: $0.text)
            }
        )
        let body = try chatEncoder.encode(payload)
        let data = try await chatPost("/chat", body: body, bearer: token)
        return try chatDecoder.decode(ChatResponseDTO.self, from: data)
    }
}

private extension APIClient {
    var chatDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    var chatEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    func chatCurrentToken() async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            guard let user = Auth.auth().currentUser else {
                cont.resume(throwing: APIError.unauthorized); return
            }
            user.getIDToken { token, error in
                if let token { cont.resume(returning: token) }
                else         { cont.resume(throwing: error ?? APIError.unauthorized) }
            }
        }
    }

    func chatPost(_ path: String, body: Data, bearer: String) async throws -> Data {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.serverError(0) }
        if http.statusCode == 429 { return data }   // surface rate-limit body to caller
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
        }
        return data
    }
}
