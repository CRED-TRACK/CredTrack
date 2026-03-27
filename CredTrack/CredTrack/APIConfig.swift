import Foundation

enum APIConfig {
    static var baseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:8080"
    }
}
