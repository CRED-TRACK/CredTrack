import Foundation
import UIKit
import FirebaseAuth

// MARK: - Response models

struct LoginResponse: Decodable {
    let id:    String
    let email: String
    let name:  String?
}

struct UserCardDTO: Decodable, Identifiable, Hashable {
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
    // Payment info
    let statementBalance:  Double?
    let minimumDue:        Double?
    let paymentDueDate:    String?   // "YYYY-MM-DD"
    let lastPaymentDate:   String?   // "YYYY-MM-DD"
    let lastPaymentAmount: Double?
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

struct BINResponse: Decodable {
    let brand:      String?
    let issuerName: String?
    let bankKey:    String?
}

struct GmailStatusResponse: Decodable {
    let connected:    Bool
    let gmailAddress: String?
    let lastSyncedAt: String?
}

private struct GmailAuthURLResponse: Decodable {
    let authUrl: String
}

struct AddCardRequest: Encodable {
    let cardProductId:  Int
    let cardHolderName: String
    let lastFour:       String
    let creditLimit:    Double?
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

struct CardStatementDTO: Decodable, Identifiable {
    let id:               Int
    let userCardId:       Int?
    let cardLastFour:     String?
    let bank:             String?
    let statementDate:    String?   // "YYYY-MM-DD"
    let statementBalance: Double?
    let minimumDue:       Double?
    let dueDate:          String?   // "YYYY-MM-DD"
    let viewStatementUrl: String?
    let makePaymentUrl:   String?
}

struct SpringPage<T: Decodable>: Decodable {
    let content:       [T]
    let totalElements: Int
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

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: Auth

    func login(token: String) async throws -> LoginResponse {
        let data = try await get("/auth/login", bearerToken: token)
        return try decoder.decode(LoginResponse.self, from: data)
    }

    // MARK: Card Products

    /// Pass `issuer` to filter by bank — used in add-card flow after BIN lookup.
    func fetchCardProducts(issuer: String? = nil) async throws -> [CardProductDTO] {
        var path = "/card-products"
        if let issuer, !issuer.isEmpty,
           let encoded = issuer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?issuer=\(encoded)"
        }
        let data = try await get(path)
        return try decoder.decode([CardProductDTO].self, from: data)
    }

    // MARK: BIN Lookup

    func lookupBIN(_ cardNumber: String) async throws -> BINResponse {
        let digits = String(cardNumber.filter(\.isNumber).prefix(8))
        let data   = try await get("/bins/\(digits)")
        return try decoder.decode(BINResponse.self, from: data)
    }

    // MARK: User Cards

    func fetchUserCards(includeInactive: Bool = false) async throws -> [UserCardDTO] {
        let token = try await currentToken()
        let path  = includeInactive ? "/user-cards?include_inactive=true" : "/user-cards"
        let data  = try await get(path, bearerToken: token)
        return try decoder.decode([UserCardDTO].self, from: data)
    }

    func addUserCard(_ req: AddCardRequest) async throws -> UserCardDTO {
        let token = try await currentToken()
        let body  = try encoder.encode(req)
        let data  = try await post("/user-cards", body: body, bearerToken: token)
        return try decoder.decode(UserCardDTO.self, from: data)
    }

    // MARK: Statements

    func fetchStatements(cardId: Int, page: Int = 0, size: Int = 20) async throws -> SpringPage<CardStatementDTO> {
        let token = try await currentToken()
        let data  = try await get("/statements?cardId=\(cardId)&page=\(page)&size=\(size)", bearerToken: token)
        return try decoder.decode(SpringPage<CardStatementDTO>.self, from: data)
    }

    // MARK: Gmail

    func fetchGmailStatus() async throws -> GmailStatusResponse {
        let token = try await currentToken()
        let data  = try await get("/gmail/status", bearerToken: token)
        return try decoder.decode(GmailStatusResponse.self, from: data)
    }

    func fetchGmailAuthURL() async throws -> String {
        let token = try await currentToken()
        let data  = try await get("/gmail/oauth/authorize", bearerToken: token)
        return try decoder.decode(GmailAuthURLResponse.self, from: data).authUrl
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

    private func post(_ path: String, body: Data, bearerToken: String? = nil) async throws -> Data {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else { throw APIError.invalidURL }
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody   = body
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
