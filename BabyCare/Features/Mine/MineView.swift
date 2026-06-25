import SwiftUI

struct MineView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingBabyProfile = false
    @State private var showingReminderSettings = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDisclaimer = false

    var body: some View {
        NavigationStack {
            List {
                // Baby profile header
                Section {
                    babyProfileRow
                }

                Section("功能") {
                    NavigationLink {
                        ReminderSettingsView()
                    } label: {
                        Label("提醒设置", systemImage: "bell.fill")
                    }

                    Button {
                        // TODO: Export data
                    } label: {
                        Label("数据导出", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }
                }

                Section("关于") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("隐私设置", systemImage: "lock.shield.fill")
                    }

                    NavigationLink {
                        DisclaimerView()
                    } label: {
                        Label("免责声明", systemImage: "doc.text.fill")
                    }

                    LabeledContent("版本") {
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingBabyProfile) {
                BabyProfileEditView()
            }
        }
    }

    private var babyProfileRow: some View {
        Button {
            showingBabyProfile = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.pink.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay { Text("👶").font(.system(size: 28)) }

                VStack(alignment: .leading, spacing: 3) {
                    if let baby = appState.currentBaby {
                        Text(baby.nickname)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("月龄 \(baby.ageDescription) · \(baby.gender.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("添加宝宝档案")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("点击填写宝宝信息")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Baby Profile Edit
struct BabyProfileEditView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var birthday = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var gender: Baby.Gender = .male

    var body: some View {
        NavigationStack {
            Form {
                Section("宝宝信息") {
                    TextField("昵称", text: $nickname)
                    DatePicker("出生日期", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    Picker("性别", selection: $gender) {
                        ForEach(Baby.Gender.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                }

                Section {
                    Button("保存") {
                        let baby = Baby(name: nickname, nickname: nickname.isEmpty ? "宝宝" : nickname, birthday: birthday, gender: gender)
                        appState.currentBaby = baby
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(Color.pink)
                }
            }
            .navigationTitle("宝宝档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if let baby = appState.currentBaby {
                    nickname = baby.nickname
                    birthday = baby.birthday
                    gender = baby.gender
                }
            }
        }
    }
}

// MARK: - Reminder Settings
struct ReminderSettingsView: View {
    @State private var feedingReminder = true
    @State private var feedingInterval = 3.0
    @State private var diaperReminder = false
    @State private var customReminder = false

    var body: some View {
        Form {
            Section("喂养提醒") {
                Toggle("开启喂养提醒", isOn: $feedingReminder)
                if feedingReminder {
                    VStack(alignment: .leading) {
                        Text("提醒间隔：\(Int(feedingInterval)) 小时")
                            .font(.subheadline)
                        Slider(value: $feedingInterval, in: 1...6, step: 0.5)
                    }
                }
            }

            Section("换尿不湿提醒") {
                Toggle("开启换尿不湿提醒", isOn: $diaperReminder)
            }

            Section("自定义提醒") {
                Toggle("开启自定义提醒", isOn: $customReminder)
            }
        }
        .navigationTitle("提醒设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("""
            隐私政策

            BabyCare AI 高度重视您和宝宝的数据隐私安全。

            数据存储：
            所有数据均存储在您的设备本地，不会上传至服务器。

            数据使用：
            记录数据仅用于在应用内展示和分析，不用于广告或第三方用途。

            数据删除：
            您可以随时在此页面删除所有数据，删除后不可恢复。
            """)
            .padding(20)
        }
        .navigationTitle("隐私设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Disclaimer
struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("医疗免责声明")
                    .font(.title2.bold())

                Text("""
                BabyCare AI 提供的所有内容（包括但不限于育儿建议、症状分析、风险提示）仅供参考，不构成医疗诊断或治疗建议。

                重要提示：
                • 本应用不能替代专业医生的诊断和治疗
                • 如宝宝出现任何异常症状，请及时就医
                • 紧急情况请立即拨打 120 或前往最近医院急诊

                使用本应用即表示您已理解并同意本免责声明。
                """)
                .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle("免责声明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MineView()
        .environmentObject(AppState())
}
