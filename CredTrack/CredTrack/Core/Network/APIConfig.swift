import Foundation

enum APIConfig {
    static var baseURL: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        return "http://localhost:8080"
    }
}
