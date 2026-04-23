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
    let isPaid:           Bool?
    let paidAmount:       Double?
    let paymentDate:      String?   // "YYYY-MM-DD"
    let hasPdf:           Bool?
    let pdfStatus:        String?   // PENDING | EXTRACTING | AWAITING_CONFIRMATION | WRONG_STATEMENT | EXTRACTED | FAILED | nil
}

struct StatementExtractionResultDTO: Decodable {
    let status:             String?
    let validationIssues:   [String]?
    let failureReason:      String?
    let bank:               String?
    let cardLastFour:       String?
    let statementDate:      String?
    let billingPeriodStart: String?
    let billingPeriodEnd:   String?
    let statementBalance:   Double?
    let minimumDue:         Double?
    let dueDate:            String?
    let transactions:       [ExtractedTransactionDTO]?

    struct ExtractedTransactionDTO: Decodable {
        let date:         String?
        let merchantName: String?
        let amount:       Double?
        let type:         String?
    }
}

struct BillExtractionResultDTO: Decodable {
    let status:             String?
    let validationIssues:   [String]?
    let failureReason:      String?
    let billerName:         String?
    let accountLastFour:    String?
    let billDate:           String?
    let billingPeriodStart: String?
    let billingPeriodEnd:   String?
    let amountDue:          Double?
    let dueDate:            String?
}

struct SpringPage<T: Decodable>: Decodable {
    let content:       [T]
    let totalElements: Int
}

struct TransactionDTO: Decodable, Identifiable {
    let id:               Int
    let merchantName:     String?
    let merchantCategory: String?
    let amount:           Double?
    let currency:         String?
    let transactionDate:  String?   // "YYYY-MM-DD"
    let transactionType:  String?   // "DEBIT" or "CREDIT"
    let status:           String?
    let bankKey:          String?
    let cardLastFour:     String?
    let description:      String?
}

struct UnbilledSpendDTO: Decodable {
    let userCardId:    Int?
    let since:         String?   // "YYYY-MM-DD" — last statement closing date, nil if no statements
    let unbilledTotal: Double?
    let transactions:  [TransactionDTO]?
}

// MARK: - Utility DTOs

struct UtilityAccountDTO: Decodable, Identifiable, Hashable {
    let id:               Int
    let billerName:       String
    let accountLastFour:  String
    let createdAt:        String?
}

struct UtilityPaymentDTO: Decodable, Identifiable {
    let id:            Int
    let paymentAmount: Double?
    let paymentDate:   String?   // "YYYY-MM-DD"
}

struct UtilityBillDTO: Decodable, Identifiable {
    let id:                  Int
    let billerName:          String
    let accountLastFour:     String
    let amountDue:           Double?
    let dueDate:             String?   // "YYYY-MM-DD"
    let billDate:            String?   // "YYYY-MM-DD"
    let billingPeriodStart:  String?   // "YYYY-MM-DD"
    let billingPeriodEnd:    String?   // "YYYY-MM-DD"
    let isPaid:              Bool?
    let totalPaid:           Double?
    let hasPdf:              Bool?
    let pdfStatus:           String?   // PENDING | EXTRACTING | AWAITING_CONFIRMATION | WRONG_STATEMENT | EXTRACTED | FAILED | nil
    let payments:            [UtilityPaymentDTO]?
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

    func markStatementPaid(statementId: Int, paymentDate: String, paidAmount: Double?) async throws -> CardStatementDTO {
        struct Body: Encodable { let paymentDate: String; let paidAmount: Double? }
        let body  = try encoder.encode(Body(paymentDate: paymentDate, paidAmount: paidAmount))
        let token = try await currentToken()
        let data  = try await post("/statements/\(statementId)/mark-paid", body: body, bearerToken: token)
        return try decoder.decode(CardStatementDTO.self, from: data)
    }

    // MARK: Transactions

    func fetchTransactions(cardId: Int, page: Int = 0, size: Int = 20) async throws -> SpringPage<TransactionDTO> {
        let token = try await currentToken()
        let data  = try await get("/transactions?cardId=\(cardId)&page=\(page)&size=\(size)", bearerToken: token)
        return try decoder.decode(SpringPage<TransactionDTO>.self, from: data)
    }

    func fetchUnbilledSpend(cardId: Int) async throws -> UnbilledSpendDTO {
        let token = try await currentToken()
        let data  = try await get("/statements/unbilled?cardId=\(cardId)", bearerToken: token)
        return try decoder.decode(UnbilledSpendDTO.self, from: data)
    }

    @discardableResult
    func uploadStatementPdf(statementId: Int, pdfData: Data) async throws -> CardStatementDTO {
        let token    = try await currentToken()
        let boundary = "Boundary-\(UUID().uuidString)"
        var body     = Data()

        let append: (String) -> Void = { body.append(Data($0.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"statement.pdf\"\r\n")
        append("Content-Type: application/pdf\r\n\r\n")
        body.append(pdfData)
        append("\r\n--\(boundary)--\r\n")

        guard let url = URL(string: "\(APIConfig.baseURL)/statements/\(statementId)/upload-pdf") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError(0) }
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
        }
        return try decoder.decode(CardStatementDTO.self, from: data)
    }

    func downloadStatementPdf(statementId: Int) async throws -> Data {
        let token = try await currentToken()
        return try await get("/statements/\(statementId)/pdf", bearerToken: token)
    }

    @discardableResult
    func uploadUtilityBillPdf(billId: Int, pdfData: Data) async throws -> UtilityBillDTO {
        let token    = try await currentToken()
        let boundary = "Boundary-\(UUID().uuidString)"
        var body     = Data()

        let append: (String) -> Void = { body.append(Data($0.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"bill.pdf\"\r\n")
        append("Content-Type: application/pdf\r\n\r\n")
        body.append(pdfData)
        append("\r\n--\(boundary)--\r\n")

        guard let url = URL(string: "\(APIConfig.baseURL)/utility-bills/\(billId)/upload-pdf") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError(0) }
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
        }
        return try decoder.decode(UtilityBillDTO.self, from: data)
    }

    func downloadUtilityBillPdf(billId: Int) async throws -> Data {
        let token = try await currentToken()
        return try await get("/utility-bills/\(billId)/pdf", bearerToken: token)
    }

    // MARK: PDF Extraction — Statements

    func fetchStatement(statementId: Int) async throws -> CardStatementDTO {
        let token = try await currentToken()
        let data  = try await get("/statements/\(statementId)", bearerToken: token)
        return try decoder.decode(CardStatementDTO.self, from: data)
    }

    func fetchStatementExtractionPreview(statementId: Int) async throws -> StatementExtractionResultDTO {
        let token = try await currentToken()
        let data  = try await get("/statements/\(statementId)/extraction-preview", bearerToken: token)
        return try decoder.decode(StatementExtractionResultDTO.self, from: data)
    }

    func applyStatementExtraction(statementId: Int, force: Bool = false) async throws -> CardStatementDTO {
        struct Body: Encodable { let force: Bool }
        let body  = try encoder.encode(Body(force: force))
        let token = try await currentToken()
        let data  = try await post("/statements/\(statementId)/apply-extraction", body: body, bearerToken: token)
        return try decoder.decode(CardStatementDTO.self, from: data)
    }

    // MARK: PDF Extraction — Utility Bills

    func fetchBill(billId: Int) async throws -> UtilityBillDTO {
        let token = try await currentToken()
        let data  = try await get("/utility-bills/\(billId)", bearerToken: token)
        return try decoder.decode(UtilityBillDTO.self, from: data)
    }

    func fetchBillExtractionPreview(billId: Int) async throws -> BillExtractionResultDTO {
        let token = try await currentToken()
        let data  = try await get("/utility-bills/\(billId)/extraction-preview", bearerToken: token)
        return try decoder.decode(BillExtractionResultDTO.self, from: data)
    }

    func applyBillExtraction(billId: Int, force: Bool = false) async throws -> UtilityBillDTO {
        struct Body: Encodable { let force: Bool }
        let body  = try encoder.encode(Body(force: force))
        let token = try await currentToken()
        let data  = try await post("/utility-bills/\(billId)/apply-extraction", body: body, bearerToken: token)
        return try decoder.decode(UtilityBillDTO.self, from: data)
    }

    // MARK: Utility Accounts

    func fetchUtilityAccounts() async throws -> [UtilityAccountDTO] {
        let token = try await currentToken()
        let data  = try await get("/utility-accounts", bearerToken: token)
        return try decoder.decode([UtilityAccountDTO].self, from: data)
    }

    struct AddUtilityAccountRequest: Encodable {
        let billerName:      String
        let accountLastFour: String
    }

    @discardableResult
    func addUtilityAccount(billerName: String, accountLastFour: String) async throws -> UtilityAccountDTO {
        let token = try await currentToken()
        let body  = try encoder.encode(AddUtilityAccountRequest(billerName: billerName,
                                                                 accountLastFour: accountLastFour))
        let data  = try await post("/utility-accounts", body: body, bearerToken: token)
        return try decoder.decode(UtilityAccountDTO.self, from: data)
    }

    func deleteUserCard(id: Int) async throws {
        let token = try await currentToken()
        try await delete("/user-cards/\(id)", bearerToken: token)
    }

    func deleteUtilityAccount(id: Int) async throws {
        let token = try await currentToken()
        try await delete("/utility-accounts/\(id)", bearerToken: token)
    }

    // MARK: Utility Bills

    func markUtilityBillPaid(billId: Int, paymentDate: String, paidAmount: Double?) async throws -> UtilityBillDTO {
        struct Body: Encodable { let paymentDate: String; let paidAmount: Double? }
        let body  = try encoder.encode(Body(paymentDate: paymentDate, paidAmount: paidAmount))
        let token = try await currentToken()
        let data  = try await post("/utility-bills/\(billId)/mark-paid", body: body, bearerToken: token)
        return try decoder.decode(UtilityBillDTO.self, from: data)
    }

    func fetchUtilityBills(billerName: String? = nil,
                           accountLastFour: String? = nil) async throws -> [UtilityBillDTO] {
        let token = try await currentToken()
        var path  = "/utility-bills"
        if let b = billerName, !b.isEmpty,
           let encoded = b.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?billerName=\(encoded)"
        }
        let data = try await get(path, bearerToken: token)
        let all  = try decoder.decode([UtilityBillDTO].self, from: data)
        // Filter by accountLastFour client-side (backend only filters by billerName)
        if let last4 = accountLastFour, !last4.isEmpty {
            return all.filter { $0.accountLastFour == last4 }
        }
        return all
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

    private func delete(_ path: String, bearerToken: String? = nil) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else { throw APIError.invalidURL }
        var request        = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError(0) }
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.serverError(http.statusCode)
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
