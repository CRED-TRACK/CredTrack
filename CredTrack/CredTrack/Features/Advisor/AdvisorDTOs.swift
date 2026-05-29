import Foundation

// MARK: - Server response shapes (snake_case auto-decoded via APIClient's decoder)

struct AdvisorDashboardDTO: Decodable {
    let asOf: String                         // "YYYY-MM-DD"
    let fiscalYearStart: String              // "YYYY-MM-DD"
    let currentQuarter: String               // "2026-Q2"
    let categoriesActive: [String]
    let categoryRankings: [CategoryRankingDTO]
    let cards: [AdvisorCardSectionDTO]
}

struct CategoryRankingDTO: Decodable, Identifiable {
    var id: String { category }
    let category: String
    let displayName: String
    let bestUserCardId: Int
    let bestRateBps: Int
    let capRemaining: Double?
    let capPeriodLabel: String?
}

struct AdvisorCardSectionDTO: Decodable, Identifiable {
    var id: Int { userCardId }
    let userCardId: Int
    let productName: String
    let issuerName: String
    let bankKey: String?
    let faceColor: String
    let gradientEnd: String
    let textColor: String
    let lastFour: String?
    let nickname: String?
    let rewards: [AdvisorRewardRuleDTO]
    let warnings: [AdvisorWarningDTO]
}

struct AdvisorRewardRuleDTO: Decodable, Identifiable, Hashable {
    var id: String { canonicalCategory }
    let canonicalCategory: String
    let displayName: String
    let iconHint: String?
    let rateBps: Int
    let effectiveRateBps: Int
    let baseRateBps: Int?
    let capAmount: Double?
    let capPeriod: String?
    let capPeriodLabel: String?
    let capGroupKey: String?
    let spentInPeriod: Double?
    let capRemaining: Double?
    let capExhausted: Bool
    let requiresUserChoice: Bool
    let userChoiceActive: String?
    let channelRestriction: String?
    let exclusions: [String]
    let notes: String?
    let source: String                       // SEED | LLM_SCRAPED | USER_OVERRIDE
    let sourceConfidence: Double?
    let sourceDocumentId: Int?
    let effectiveFrom: String?               // "YYYY-MM-DD"
    let effectiveTo: String?

    var ratePercent: Double { Double(effectiveRateBps) / 100.0 }
    var rateLabel: String {
        let pct = Double(effectiveRateBps) / 100.0
        return pct.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(pct))%"
            : String(format: "%.2g%%", pct)
    }
}

struct AdvisorWarningDTO: Decodable, Identifiable, Hashable {
    var id: String { code }
    let code: String                         // BOA_3PCT_CHOICE_MISSING | ...
    let message: String
}

struct AdvisorCategoryDTO: Decodable, Identifiable, Hashable {
    var id: String { code }
    let code: String
    let displayName: String
    let iconHint: String
    let commonMerchants: [String]
}

struct CategoryChoiceResponseDTO: Decodable {
    let id: Int
    let userCardId: Int
    let choiceKind: String
    let canonicalCategory: String
    let effectiveFrom: String?
    let effectiveTo: String?
}

private struct CategoryChoiceRequestDTO: Encodable {
    let choiceKind: String
    let canonicalCategory: String
}

// MARK: - APIClient extension

extension APIClient {
    func fetchAdvisorDashboard() async throws -> AdvisorDashboardDTO {
        let token = try await advisorCurrentToken()
        let data  = try await advisorGet("/recommendations/dashboard", bearer: token)
        return try advisorDecoder.decode(AdvisorDashboardDTO.self, from: data)
    }

    func fetchAdvisorCategories() async throws -> [AdvisorCategoryDTO] {
        let token = try await advisorCurrentToken()
        let data  = try await advisorGet("/recommendations/categories", bearer: token)
        return try advisorDecoder.decode([AdvisorCategoryDTO].self, from: data)
    }

    @discardableResult
    func setAdvisorCategoryChoice(userCardId: Int,
                                  choiceKind: String,
                                  canonicalCategory: String) async throws -> CategoryChoiceResponseDTO {
        let token = try await advisorCurrentToken()
        let body  = try advisorEncoder.encode(CategoryChoiceRequestDTO(
            choiceKind: choiceKind, canonicalCategory: canonicalCategory))
        let data  = try await advisorPut("/user-cards/\(userCardId)/category-choice",
                                          body: body, bearer: token)
        return try advisorDecoder.decode(CategoryChoiceResponseDTO.self, from: data)
    }
}

// MARK: - Private helpers (kept here so we don't touch APIClient.swift)

private extension APIClient {
    var advisorDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    var advisorEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    func advisorCurrentToken() async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            guard let user = FirebaseAuthBridge.currentUser() else {
                cont.resume(throwing: APIError.unauthorized); return
            }
            user.getIDToken { token, error in
                if let token { cont.resume(returning: token) }
                else         { cont.resume(throwing: error ?? APIError.unauthorized) }
            }
        }
    }

    func advisorGet(_ path: String, bearer: String) async throws -> Data {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.serverError(0) }
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
        }
        return data
    }

    func advisorPut(_ path: String, body: Data, bearer: String) async throws -> Data {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.serverError(0) }
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
        }
        return data
    }
}

// Tiny shim so we don't import FirebaseAuth at file scope unnecessarily.
import FirebaseAuth
private enum FirebaseAuthBridge {
    static func currentUser() -> User? { Auth.auth().currentUser }
}
