import SwiftUI

struct DataMigrationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var migration = MigrationService()
    @Environment(\.dismiss) private var dismiss
    @State private var rotationAngle: Double = 0

    private var iconName: String {
        if let _ = migration.error { return "xmark.circle.fill" }
        if migration.progress >= 1.0 { return "checkmark.circle.fill" }
        return migration.isRunning ? "arrow.triangle.2.circlepath" : "icloud.and.arrow.up"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundStyle(migration.error != nil ? .red : .pink)
                    .rotationEffect(.degrees(migration.isRunning ? rotationAngle : 0))
                    .animation(migration.isRunning ?
                        .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: rotationAngle)
                    .onChange(of: migration.isRunning) { _, running in
                        rotationAngle = running ? 360 : 0
                    }

                // Title
                Text(migration.error != nil ? "同步失败" :
                     (migration.progress >= 1.0 ? "同步完成" : "同步数据到服务端"))
                    .font(.title2.bold())

                // Progress
                if migration.isRunning || migration.progress > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: migration.progress)
                            .tint(.pink)
                            .padding(.horizontal, 32)

                        Text(migration.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Error message
                if let err = migration.error {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Action buttons
                VStack(spacing: 12) {
                    if !migration.isRunning && migration.progress < 1.0 {
                        Button {
                            Task { await migration.migrate(baby: appState.currentBaby) }
                        } label: {
                            Label(migration.error != nil ? "重试" : "开始同步",
                                  systemImage: migration.error != nil ? "arrow.clockwise" : "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .padding(.horizontal, 32)
                    }

                    if migration.progress >= 1.0 {
                        Button("完成") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.pink)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 32)
                    }

                    if !migration.isRunning {
                        Button("取消", role: .cancel) { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .navigationTitle("导入本地数据")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(migration.isRunning)
        }
    }
}

#Preview {
    DataMigrationView().environmentObject(AppState())
}
