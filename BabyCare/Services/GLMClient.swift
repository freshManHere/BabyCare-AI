import Foundation

// MARK: - Shared Message Model

struct GLMMessage: Codable {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}

// MARK: - Response Models

struct GLMResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: GLMMessage?
        let delta: Delta?
        let finishReason: String?
        enum CodingKeys: String, CodingKey {
            case message, delta
            case finishReason = "finish_reason"
        }
    }
    struct Delta: Decodable {
        let content: String?
    }
}

// MARK: - Error

enum GLMError: Error, LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "API 地址错误"
        case .httpError(401, _):       return "登录已过期，请重新登录"
        case .httpError(429, _):       return "请求过于频繁，请稍后再试"
        case .httpError(let c, let m): return "请求失败（\(c)）：\(m)"
        case .decodingError:           return "响应解析失败，请重试"
        case .unknown:                 return "未知错误，请重试"
        }
    }
}

// MARK: - GLM Client
// Requests now go through the self-hosted backend (/ai/chat), which proxies to GLM.
// The GLM API key lives only on the server — never in the iOS app.

final class GLMClient: Sendable {
    nonisolated(unsafe) static let shared = GLMClient()
    private init() {}

    // MARK: - Streaming chat via backend proxy
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

        // Encode only messages — backend adds model/temperature/stream
        struct BackendChatRequest: Encodable {
            let messages: [GLMMessage]
        }
        let body = BackendChatRequest(messages: messages)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Skip ngrok browser warning page for non-browser clients
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        // Attach JWT from Keychain (safer than UserDefaults)
        if let token = KeychainHelper.load(key: "access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder().encode(body)

        Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
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

                // Parse SSE lines forwarded by the backend
                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let payload = String(line.dropFirst(6))
                    guard payload != "[DONE]" else { break }
                    guard let data = payload.data(using: .utf8) else { continue }
                    do {
                        let resp = try JSONDecoder().decode(GLMResponse.self, from: data)
                        if let delta = resp.choices.first?.delta?.content, !delta.isEmpty {
                            await MainActor.run { onDelta(delta) }
                        }
                    } catch {
                        // Skip malformed SSE chunks
                    }
                }
                await MainActor.run { onComplete() }
            } catch {
                await MainActor.run { onError(.unknown) }
            }
        }
    }
}
