import Foundation

// MARK: - Request / Response Models

struct GLMChatRequest: Encodable {
    let model: String
    let messages: [GLMMessage]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }
}

struct GLMMessage: Codable {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}

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
    case noAPIKey
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .noAPIKey:          return "未配置 API Key，请在「我的 → AI 助手设置」中添加"
        case .invalidURL:        return "API 地址错误"
        case .httpError(401, _): return "API Key 无效，请在设置中重新配置"
        case .httpError(429, _): return "请求过于频繁，请稍后再试"
        case .httpError(let c, let m): return "请求失败（\(c)）：\(m)"
        case .decodingError:     return "响应解析失败，请重试"
        case .unknown:           return "未知错误，请重试"
        }
    }
}

// MARK: - GLM Client

final class GLMClient: Sendable {
    nonisolated(unsafe) static let shared = GLMClient()
    private init() {}

    // MARK: - Streaming chat (async sequence of text deltas)
    func streamChat(
        messages: [GLMMessage],
        onDelta: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (GLMError) -> Void
    ) {
        guard AIConfig.hasAPIKey else {
            Task { @MainActor in onError(.noAPIKey) }
            return
        }
        let apiKey = AIConfig.apiKey
        guard let url = URL(string: "\(AIConfig.baseURL)/chat/completions") else {
            Task { @MainActor in onError(.invalidURL) }
            return
        }

        let body = GLMChatRequest(
            model: AIConfig.model,
            messages: messages,
            stream: true,
            temperature: 0.7,
            maxTokens: 1024
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                        onError(.httpError(httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)))
                    }
                    return
                }

                // Parse SSE lines
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
