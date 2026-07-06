import SwiftUI

struct AssistantView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputText = ""
    @State private var showAPIKeyAlert = false

    private var viewModel: AssistantViewModel { appState.assistantViewModel }

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.pink)
                    }
                }
            }
            .alert("需要配置 API Key", isPresented: $showAPIKeyAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("请点击右上角「设置」图标，添加智谱 AI 的 API Key，才能使用 AI 助手功能。")
            }
        }
    }

    // MARK: - Chat Area
    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        VStack(spacing: 4) {
                            ChatBubble(message: message)
                            // Only show banner for high-risk responses
                            if message.role == .assistant, !message.text.isEmpty {
                                let risk = RiskDetector.detect(in: message.text)
                                if risk == .high {
                                    RiskBannerView(level: risk)
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .id(message.id)
                    }
                    if viewModel.isLoading {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .id("loading")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    if let last = viewModel.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if loading { withAnimation { proxy.scrollTo("loading", anchor: .bottom) } }
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                if let last = viewModel.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
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
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Send
    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard AIConfig.hasAPIKey else {
            showAPIKeyAlert = true
            return
        }
        inputText = ""
        viewModel.sendMessage(trimmed, baby: appState.currentBaby)
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date

    init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = Date()
    }

    // Preserve id & timestamp when appending streaming deltas
    private init(id: UUID, role: Role, text: String, timestamp: Date) {
        self.id = id; self.role = role; self.text = text; self.timestamp = timestamp
    }

    func appending(_ delta: String) -> ChatMessage {
        ChatMessage(id: id, role: role, text: text + delta, timestamp: timestamp)
    }

    enum Role { case user, assistant }
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
                    if message.text.isEmpty {
                        TypingIndicator()
                    } else {
                        Text(message.text)
                            .font(.subheadline)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
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
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Risk Banner
struct RiskBannerView: View {
    let level: RiskLevel

    private var color: Color { level == .high ? .red : .orange }
    private var icon: String { level == .high ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill" }
    private var title: String { level == .high ? "建议立即就医" : "建议就医确认" }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.caption.bold()).foregroundStyle(color)
            Spacer()
            if level == .high {
                Button {
                    if let url = URL(string: "tel://120") { UIApplication.shared.open(url) }
                } label: {
                    Text("拨打120")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.red).foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            Button {
                if let url = URL(string: "maps://?q=儿科医院") { UIApplication.shared.open(url) }
            } label: {
                Text("查找医院")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(color.opacity(0.15)).foregroundStyle(color)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .environmentObject(AppState())
}
