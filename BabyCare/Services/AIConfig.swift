import Foundation

enum AIConfig {
    /// Base URL of the self-hosted backend (ngrok or cloud)
    static let serverBaseURL = "https://paralyze-unfair-fetch.ngrok-free.dev"

    /// Endpoint the iOS app calls — backend proxies to GLM internally
    static var chatURL: String { "\(serverBaseURL)/ai/chat" }

    /// The GLM API key no longer lives in the iOS app.
    /// hasAPIKey now just checks that the server URL is set.
    static var hasAPIKey: Bool { !serverBaseURL.isEmpty }
}
