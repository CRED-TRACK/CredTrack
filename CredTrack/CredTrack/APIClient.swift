import Foundation

struct LoginResponse: Decodable {
    let id: String
    let email: String
    let name: String?
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid server URL."
        case .unauthorized:     return "Token rejected by server."
        case .serverError(let code): return "Server error (\(code))."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    func login(token: String) async throws -> LoginResponse {
        guard let url = URL(string: "\(APIConfig.baseURL)/auth/login") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }

        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
        }

        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }
}
