import SwiftUI

struct AssistantView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "你好！我是 BabyCare AI 助手 👶\n\n你可以问我关于宝宝喂养、睡眠、症状等任何问题，我会尽力帮助你。")
    ]
    @State private var isLoading = false

    private let quickQuestions = [
        "宝宝一直哭怎么办",
        "吐奶是否正常",
        "今天睡得怎么样",
        "发烧怎么办",
        "要不要看医生"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatArea
                Divider()
                quickQuestionsBar
                Divider()
                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI 助手")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Chat Area
    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if isLoading {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Quick Questions
    private var quickQuestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickQuestions, id: \.self) { question in
                    Button(question) {
                        sendMessage(question)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.pink.opacity(0.1))
                    .foregroundStyle(.pink)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入问题...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.pink)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Send
    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        inputText = ""
        isLoading = true

        // Simulated AI response — replace with real API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let response = simulatedResponse(for: trimmed)
            messages.append(ChatMessage(role: .assistant, text: response))
            isLoading = false
        }
    }

    private func simulatedResponse(for question: String) -> String {
        if question.contains("哭") {
            return "宝宝哭闹可能有以下原因：\n\n1. **饥饿** — 检查上次喂养时间，若超过2小时可尝试喂奶\n2. **需要换尿不湿** — 检查尿不湿是否需要更换\n3. **困了想睡觉** — 观察是否有揉眼睛、打哈欠的迹象\n4. **肠胀气** — 可以轻轻按摩宝宝肚子\n5. **需要安抚** — 尝试抱抱或使用安抚奶嘴\n\n如果哭声异常高亢或持续2小时以上，建议就医。"
        } else if question.contains("吐奶") {
            return "新生儿吐奶是**非常常见**的现象 😊\n\n**正常吐奶**：量少、宝宝没有痛苦表情\n\n**预防建议：**\n• 喂奶后及时拍嗝\n• 喂奶后保持竖抱15-20分钟\n• 避免喂奶后立即换尿不湿\n\n**需要就医的情况：**\n• 喷射性吐奶\n• 吐奶量很大\n• 宝宝体重不增或下降\n• 吐出物有血丝"
        } else if question.contains("发烧") {
            return "⚠️ **发烧处理指南**\n\n**根据月龄判断：**\n• **3个月以下**：体温≥38°C → 立即就医\n• **3-6个月**：体温≥38.5°C → 建议就医\n• **6个月以上**：体温≥39°C 或持续超过2天 → 就医\n\n**家庭护理：**\n• 多补充液体（母乳/奶粉/水）\n• 保持室温适宜（22-24°C）\n• 穿着不要过厚\n• 物理降温：温水擦浴"
        } else if question.contains("睡") {
            return "我来帮你分析今日睡眠情况 💤\n\n请在记录页查看今日睡眠记录，我可以帮你判断睡眠总时长是否达标。\n\n**各月龄参考睡眠时长：**\n• 0-3月：14-17小时\n• 4-11月：12-15小时\n\n建议保持规律的作息时间，培养良好的睡眠习惯。"
        } else if question.contains("医生") || question.contains("就医") {
            return "**以下情况需要及时就医：**\n\n🔴 **立即就医：**\n• 3个月以下发烧≥38°C\n• 呼吸困难、口唇发紫\n• 抽搐\n• 无法唤醒或极度嗜睡\n\n🟡 **24小时内就医：**\n• 持续高烧超过2天\n• 反复呕吐\n• 大量腹泻（可能脱水）\n• 皮疹伴发烧"
        } else {
            return "感谢你的提问！我正在学习更多育儿知识来更好地帮助你 🌟\n\n如果你有关于喂养、睡眠、症状的具体问题，我可以提供更精准的建议。你也可以在「记录」页记录宝宝的日常，我会基于记录数据给出个性化分析。"
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp = Date()

    enum Role {
        case user, assistant
    }
}

// MARK: - Chat Bubble
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Circle()
                    .fill(Color.pink.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay { Text("🤖").font(.system(size: 16)) }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(message.text))
                        .font(.subheadline)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .clipShape(.rect(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.subheadline)
                        .padding(12)
                        .background(Color.pink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .clipShape(.rect(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16))

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.3 : 0.8)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { phase = 1 }
    }
}

#Preview {
    AssistantView()
}
