import SwiftUI

struct AISettingsView: View {
    private var maskedKey: String? {
        let k = AIConfig.apiKey
        guard !k.isEmpty && k != "YOUR_API_KEY_HERE" else { return nil }
        return "••••••••••••••••" + String(k.suffix(6))
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("GLM-4-Flash（智谱 AI）", systemImage: "cpu")
                        .font(.subheadline.bold())
                    Text("永久免费模型，由智谱 AI 提供支持")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("API Key") {
                if let masked = maskedKey {
                    LabeledContent("当前 Key", value: masked)
                        .font(.subheadline)
                } else {
                    Text("未配置（请联系开发者）")
                        .foregroundStyle(.secondary)
                }
            }

            Section("模型信息") {
                LabeledContent("模型", value: AIConfig.model)
                LabeledContent("服务地址", value: "open.bigmodel.cn")
            }
        }
        .navigationTitle("AI 助手设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AISettingsView() }
}
