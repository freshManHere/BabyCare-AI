import Foundation

enum AIConfig {
    static let baseURL = "https://open.bigmodel.cn/api/paas/v4"
    static let model   = "glm-4-flash"
    static var apiKey: String { Secrets.glmAPIKey }
    static var hasAPIKey: Bool { !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" }
}
