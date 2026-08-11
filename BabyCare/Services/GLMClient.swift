import Foundation

// MARK: - Shared Message Model

struct GLMMessage: Codable {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}

// MARK: - Error

enum GLMError: Error, LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "API 地址错误"
        case .httpError(401, _):       return "登录已过期，请重新登录"
        case .httpError(429, _):       return "请求过于频繁，请稍后再试"
        case .httpError(let c, let m): return "请求失败（\(c)）：\(m)"
        case .unknown:                 return "未知错误，请重试"
        }
    }
}

// MARK: - GLM Client
// Requests now go through the self-hosted backend (/ai/chat), which proxies to GLM.
// The GLM API key lives only on the server — never in the iOS app.
// Non-streaming mode is used to ensure compatibility with ngrok and other proxies
// that buffer SSE responses and prevent real-time streaming.

final class GLMClient: Sendable {
    nonisolated(unsafe) static let shared = GLMClient()
    private init() {}

    // MARK: - Non-streaming chat via backend proxy
    func streamChat(
        messages: [GLMMessage],
        onDelta: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (GLMError) -> Void
    ) {
        guard let url = URL(string: AIConfig.chatURL) else {
            Task { @MainActor in onError(.invalidURL) }
            return
        }

        struct BackendChatRequest: Encodable {
            let messages: [GLMMessage]
        }
        let body = BackendChatRequest(messages: messages)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        if let token = KeychainHelper.load(key: "access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder().encode(body)

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run { onError(.unknown) }
                    return
                }
                guard httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        onError(.httpError(httpResponse.statusCode,
                                           HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)))
                    }
                    return
                }

                struct ChatResponse: Decodable { let content: String }
                let resp = try JSONDecoder().decode(ChatResponse.self, from: data)
                await MainActor.run {
                    onDelta(resp.content)
                    onComplete()
                }
            } catch {
                await MainActor.run { onError(.unknown) }
            }
        }
    }
}
