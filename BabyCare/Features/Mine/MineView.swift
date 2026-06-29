import SwiftUI
import PhotosUI
import UserNotifications

// MARK: - MineView
struct MineView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingBabyProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    babyProfileRow
                }

                Section("功能") {
                    NavigationLink {
                        GrowthChartView()
                            .environmentObject(appState)
                    } label: {
                        Label("生长记录", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationLink {
                        ReminderSettingsView()
                    } label: {
                        Label("提醒设置", systemImage: "bell.fill")
                    }

                    NavigationLink {
                        DataExportView()
                            .environmentObject(appState)
                    } label: {
                        Label("数据导出", systemImage: "square.and.arrow.up")
                    }
                }

                Section("关于") {
                    NavigationLink {
                        PrivacyPolicyView()
                            .environmentObject(appState)
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
                    .environmentObject(appState)
            }
        }
    }

    private var babyProfileRow: some View {
        Button {
            showingBabyProfile = true
        } label: {
            HStack(spacing: 14) {
                avatarView
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

    @ViewBuilder
    private var avatarView: some View {
        if let data = appState.currentBaby?.avatarData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.pink.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Text(appState.currentBaby?.gender == .female ? "👧" : "👶")
                        .font(.system(size: 28))
                }
        }
    }
}

// MARK: - #19 Baby Profile Edit
struct BabyProfileEditView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var birthday = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var gender: Baby.Gender = .male
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var avatarData: Data? = nil
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // Avatar picker
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = avatarData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.pink.opacity(0.15))
                                        .frame(width: 80, height: 80)
                                        .overlay {
                                            Text(gender == .female ? "👧" : "👶")
                                                .font(.system(size: 36))
                                        }
                                }
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(Color.pink)
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("基本信息") {
                    TextField("宝宝昵称", text: $nickname)
                    DatePicker("出生日期", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    Picker("性别", selection: $gender) {
                        ForEach(Baby.Gender.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                }

                Section {
                    Button("保存") { save() }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .listRowBackground(Color.pink)
                }

                if appState.currentBaby != nil {
                    Section {
                        Button("删除宝宝档案", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("宝宝档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
            .onAppear {
                if let baby = appState.currentBaby {
                    nickname = baby.nickname
                    birthday = baby.birthday
                    gender = baby.gender
                    avatarData = baby.avatarData
                }
            }
            .confirmationDialog("确认删除宝宝档案？此操作不可撤销。", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除档案", role: .destructive) {
                    appState.currentBaby = nil
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        var baby = Baby(
            name: name.isEmpty ? "宝宝" : name,
            nickname: name.isEmpty ? "宝宝" : name,
            birthday: birthday,
            gender: gender
        )
        baby.avatarData = avatarData
        appState.currentBaby = baby
        dismiss()
    }
}

// MARK: - #20 Reminder Settings (with UNUserNotificationCenter)
struct ReminderSettingsView: View {
    @State private var feedingEnabled = false
    @State private var feedingIntervalHours: Double = 3
    @State private var diaperEnabled = false
    @State private var diaperIntervalHours: Double = 3
    @State private var notificationPermission: UNAuthorizationStatus = .notDetermined

    private let defaults = UserDefaults.standard

    var body: some View {
        Form {
            // Permission banner
            if notificationPermission == .denied {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("通知权限已关闭")
                                .font(.subheadline.bold())
                            Text("请前往「设置」→「BabyCare」开启通知")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("去设置") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                    }
                }
                .listRowBackground(Color.orange.opacity(0.1))
            }

            Section {
                Toggle("开启喂养提醒", isOn: $feedingEnabled)
                    .onChange(of: feedingEnabled) { _, _ in save(); schedule() }
                if feedingEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("提醒间隔：每 \(Int(feedingIntervalHours)) 小时")
                            .font(.subheadline)
                        Slider(value: $feedingIntervalHours, in: 1...6, step: 0.5)
                            .onChange(of: feedingIntervalHours) { _, _ in save(); schedule() }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Label("喂养提醒", systemImage: "drop.fill")
            }

            Section {
                Toggle("开启换尿不湿提醒", isOn: $diaperEnabled)
                    .onChange(of: diaperEnabled) { _, _ in save(); schedule() }
                if diaperEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("提醒间隔：每 \(Int(diaperIntervalHours)) 小时")
                            .font(.subheadline)
                        Slider(value: $diaperIntervalHours, in: 1...6, step: 0.5)
                            .onChange(of: diaperIntervalHours) { _, _ in save(); schedule() }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Label("换尿不湿提醒", systemImage: "heart.fill")
            }

            if notificationPermission == .notDetermined {
                Section {
                    Button("开启通知权限") { requestPermission() }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .listRowBackground(Color.pink)
                }
            }
        }
        .navigationTitle("提醒设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load(); checkPermission() }
    }

    private func load() {
        feedingEnabled = defaults.bool(forKey: "reminder_feeding_enabled")
        feedingIntervalHours = defaults.double(forKey: "reminder_feeding_interval").nonZeroOr(3)
        diaperEnabled = defaults.bool(forKey: "reminder_diaper_enabled")
        diaperIntervalHours = defaults.double(forKey: "reminder_diaper_interval").nonZeroOr(3)
    }

    private func save() {
        defaults.set(feedingEnabled, forKey: "reminder_feeding_enabled")
        defaults.set(feedingIntervalHours, forKey: "reminder_feeding_interval")
        defaults.set(diaperEnabled, forKey: "reminder_diaper_enabled")
        defaults.set(diaperIntervalHours, forKey: "reminder_diaper_interval")
    }

    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async { notificationPermission = status }
        }
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationPermission = granted ? .authorized : .denied
                if granted { schedule() }
            }
        }
    }

    private func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["feeding_reminder", "diaper_reminder"])

        guard notificationPermission == .authorized else { return }

        if feedingEnabled {
            let content = UNMutableNotificationContent()
            content.title = "喂养提醒 🍼"
            content.body = "距上次喂养已过 \(Int(feedingIntervalHours)) 小时，是否需要喂奶？"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: feedingIntervalHours * 3600, repeats: true)
            center.add(UNNotificationRequest(identifier: "feeding_reminder", content: content, trigger: trigger))
        }

        if diaperEnabled {
            let content = UNMutableNotificationContent()
            content.title = "换尿不湿提醒 💛"
            content.body = "记得检查宝宝尿不湿哦～"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: diaperIntervalHours * 3600, repeats: true)
            center.add(UNNotificationRequest(identifier: "diaper_reminder", content: content, trigger: trigger))
        }
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double { self == 0 ? fallback : self }
}

// MARK: - #21 Data Export
struct DataExportView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @State private var exportStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var exportEnd = Date()
    @State private var csvString: String? = nil
    @State private var showShareSheet = false

    var body: some View {
        Form {
            Section("导出范围") {
                DatePicker("开始日期", selection: $exportStart, in: ...exportEnd, displayedComponents: .date)
                DatePicker("结束日期", selection: $exportEnd, in: exportStart..., displayedComponents: .date)
            }

            Section {
                Button("生成 CSV 并分享") { generateCSV() }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(Color.pink)
            }

            Section("说明") {
                Text("导出的 CSV 文件包含所选日期范围内的全部记录，可导入 Excel 或 Numbers 查看。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("数据导出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let csv = csvString {
                ShareSheet(activityItems: [csv])
            }
        }
    }

    private func generateCSV() {
        guard let baby = appState.currentBaby else { return }
        let start = Calendar.current.startOfDay(for: exportStart)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: exportEnd) ?? exportEnd
        let events = store.events(babyId: baby.id, from: start, to: end)

        var lines = ["时间,类型,描述,备注"]
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        for event in events {
            let time = fmt.string(from: event.startTime)
            let type = event.label.rawValue
            let desc = event.shortDescription.replacingOccurrences(of: ",", with: "，")
            let note = event.note.replacingOccurrences(of: ",", with: "，")
            lines.append("\(time),\(type),\(desc),\(note)")
        }
        csvString = lines.joined(separator: "\n")
        showShareSheet = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Privacy Policy
struct PrivacyPolicyView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策")
                    .font(.title2.bold())

                Group {
                    Text("**数据存储**")
                    Text("所有数据均存储在您的设备本地（App 沙盒），不会上传至任何服务器。")

                    Text("**数据使用**")
                    Text("记录数据仅用于 App 内展示和分析，不用于广告或第三方用途。")

                    Text("**数据删除**")
                    Text("您可以随时删除所有记录数据及宝宝档案，删除后不可恢复。")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("删除所有数据", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .navigationTitle("隐私设置")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("确认删除所有数据？此操作不可撤销，包括所有宝宝记录和档案。", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除所有数据", role: .destructive) {
                store.deleteAll()
                appState.currentBaby = nil
            }
        }
    }
}

// MARK: - Disclaimer
struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("医疗免责声明")
                    .font(.title2.bold())

                Text("BabyCare AI 提供的所有内容（包括但不限于育儿建议、症状分析、风险提示）仅供参考，不构成医疗诊断或治疗建议。")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("本应用不能替代专业医生的诊断和治疗", systemImage: "cross.circle.fill")
                    Label("如宝宝出现任何异常症状，请及时就医", systemImage: "stethoscope")
                    Label("紧急情况请立即拨打 120 或前往最近医院急诊", systemImage: "phone.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("使用本应用即表示您已理解并同意本免责声明。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
