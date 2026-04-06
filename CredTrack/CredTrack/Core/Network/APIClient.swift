import Foundation
import UIKit
import FirebaseAuth

// MARK: - Response models

struct LoginResponse: Decodable {
    let id:    String
    let email: String
    let name:  String?
}

struct UserCardDTO: Decodable {
    let id:             Int
    // Card product info (embedded so no second request needed)
    let productName:    String
    let issuerName:     String
    let bankKey:        String?
    let brand:          String
    let faceColor:      String
    let gradientEnd:    String
    let textColor:      String
    // Card identity
    let nickname:       String?
    let lastFour:       String?
    let cardHolderName: String?
    // Financials
    let creditLimit:    Double?
    let currentBalance: Double?
    // Meta
    let isActive:       Bool

    func toCardModel() -> CardModel {
        CardModel(
            cardName:    nickname ?? productName,
            bank:        issuerName,
            lastFour:    lastFour ?? "••••",
            brandString: brand,
            bankKey:     bankKey,
            faceColor:   UIColor(hex: faceColor)   ?? .darkGray,
            gradientEnd: UIColor(hex: gradientEnd) ?? .black,
            textColor:   UIColor(hex: textColor)   ?? .white
        )
    }
}

struct CardProductDTO: Decodable {
    let id:           Int
    let issuerName:   String
    let bankKey:      String?  // e.g. "CHASE" — drives logo + issuer lookup
    let productName:  String
    let officialName: String
    let brand:        String
    let faceColor:    String
    let gradientEnd:  String
    let textColor:    String

    func toCardModel() -> CardModel {
        CardModel(
            cardName:    productName,
            bank:        issuerName,
            lastFour:    "••••",
            brandString: brand,
            bankKey:     bankKey,
            faceColor:   UIColor(hex: faceColor)   ?? .darkGray,
            gradientEnd: UIColor(hex: gradientEnd) ?? .black,
            textColor:   UIColor(hex: textColor)   ?? .white
        )
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid server URL."
        case .unauthorized:            return "Token rejected by server."
        case .serverError(let code):   return "Server error (\(code))."
        }
    }
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: Auth

    func login(token: String) async throws -> LoginResponse {
        let data = try await get("/auth/login", bearerToken: token)
        return try decoder.decode(LoginResponse.self, from: data)
    }

    // MARK: Card Products

    func fetchCardProducts() async throws -> [CardProductDTO] {
        let data = try await get("/card-products")
        return try decoder.decode([CardProductDTO].self, from: data)
    }

    // MARK: User Cards

    func fetchUserCards(includeInactive: Bool = false) async throws -> [UserCardDTO] {
        let token = try await currentToken()
        let path  = includeInactive ? "/user-cards?include_inactive=true" : "/user-cards"
        let data  = try await get(path, bearerToken: token)
        return try decoder.decode([UserCardDTO].self, from: data)
    }

    // MARK: - Private helpers

    /// Returns the current Firebase ID token, refreshing it if needed.
    private func currentToken() async throws -> String {
        guard let user = Auth.auth().currentUser else { throw APIError.unauthorized }
        return try await withCheckedThrowingContinuation { cont in
            user.getIDToken { token, error in
                if let token { cont.resume(returning: token) }
                else         { cont.resume(throwing: error ?? APIError.unauthorized) }
            }
        }
    }

    private func get(_ path: String, bearerToken: String? = nil) async throws -> Data {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError(0) }
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
        }
        return data
    }
}
