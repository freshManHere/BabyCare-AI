import Foundation
import Observation

@MainActor
@Observable
final class AssistantViewModel {
    var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "你好！我是 BabyCare AI 助手 👶\n\n你可以问我关于宝宝喂养、睡眠、症状等任何问题，我会尽力帮助你。")
    ]
    var isLoading = false

    private let store = EventStore.shared

    func sendMessage(_ text: String, baby: Baby?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        isLoading = true

        let systemPrompt = AssistantContextBuilder.buildSystemPrompt(baby: baby, store: store)
        var glmMessages: [GLMMessage] = [GLMMessage(role: "system", content: systemPrompt)]
        // Truncate each history message to 2000 chars to avoid oversized payloads
        // (long AI responses can accumulate and exceed the server body limit).
        glmMessages += messages.suffix(10).map {
            let truncated = $0.text.count > 2000 ? String($0.text.prefix(2000)) + "…" : $0.text
            return GLMMessage(role: $0.role == .user ? "user" : "assistant", content: truncated)
        }

        let placeholder = ChatMessage(role: .assistant, text: "")
        messages.append(placeholder)
        let msgId = placeholder.id

        GLMClient.shared.streamChat(
            messages: glmMessages,
            onDelta: { [weak self] delta in
                guard let self else { return }
                if let idx = self.messages.firstIndex(where: { $0.id == msgId }) {
                    self.messages[idx] = self.messages[idx].appending(delta)
                }
            },
            onComplete: { [weak self] in
                self?.isLoading = false
            },
            onError: { [weak self] error in
                guard let self else { return }
                if let idx = self.messages.firstIndex(where: { $0.id == msgId }) {
                    self.messages[idx] = ChatMessage(
                        role: .assistant,
                        text: "⚠️ \(error.localizedDescription ?? "请求失败，请重试")"
                    )
                }
                self.isLoading = false
            }
        )
    }
}
