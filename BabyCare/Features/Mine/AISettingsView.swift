import SwiftUI

struct AISettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("GLM-4-Flash（智谱 AI）", systemImage: "cpu")
                        .font(.subheadline.bold())
                    Text("AI 请求由自建后端代理，API Key 存储在服务器上，不在设备中保存。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("服务地址") {
                LabeledContent("后端", value: AIConfig.serverBaseURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("模型", value: "GLM-4-Flash")
            }
        }
        .navigationTitle("AI 助手设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AISettingsView() }
}

