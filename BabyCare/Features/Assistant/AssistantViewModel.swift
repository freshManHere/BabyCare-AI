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
        glmMessages += messages.suffix(10).map {
            GLMMessage(role: $0.role == .user ? "user" : "assistant", content: $0.text)
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
