import SwiftUI

// MARK: - High risk symptom keywords
private let highRiskKeywords = [
    "抽搐", "惊厥", "呼吸困难", "口唇发紫", "发绀",
    "意识丧失", "无法唤醒", "极度嗜睡", "高热", "超高热",
    "喷射性呕吐", "大量出血", "严重腹泻"
]

struct SymptomFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time = Date()
    @State private var selectedTypes: Set<String> = []
    @State private var customType = ""
    @State private var severity: SymptomPayload.Severity = .mild
    @State private var isContinuous = false
    @State private var tempText = ""
    @State private var note = ""
    @State private var showHighRiskAlert = false

    private let commonSymptoms = [
        "发烧", "咳嗽", "流鼻涕", "鼻塞", "腹泻", "呕吐",
        "皮疹", "哭闹不止", "不吃奶", "眼屎多", "腹胀", "便秘"
    ]

    private var isHighRisk: Bool {
        let allTypes = selectedTypes.union(customType.isEmpty ? [] : [customType])
        return allTypes.contains { type in
            highRiskKeywords.contains { type.contains($0) }
        } || (severity == .severe)
    }

    var body: some View {
        Form {
            Section {
                DatePicker("记录时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
            }

            // High-risk warning banner
            if isHighRisk {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("高风险症状提示")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                            Text("当前症状可能需要紧急就医，请立即咨询医生或前往最近医院急诊。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.red.opacity(0.08))
            }

            Section("症状类型（可多选）") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(commonSymptoms, id: \.self) { symptom in
                        SelectChip(title: symptom, isSelected: selectedTypes.contains(symptom)) {
                            if selectedTypes.contains(symptom) { selectedTypes.remove(symptom) }
                            else { selectedTypes.insert(symptom) }
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                TextField("其他症状（选填）", text: $customType)
            }

            Section("严重程度") {
                Picker("程度", selection: $severity) {
                    ForEach(SymptomPayload.Severity.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("体温") {
                HStack {
                    TextField("选填", text: $tempText)
                        .keyboardType(.decimalPad)
                    Text("°C").foregroundStyle(.secondary)
                }
                if let temp = Double(tempText) {
                    let ageMonths = appState.currentBaby?.ageInMonths ?? 6
                    let warningTemp: Double = ageMonths < 3 ? 38.0 : (ageMonths < 6 ? 38.5 : 39.0)
                    if temp >= warningTemp {
                        Label("体温偏高，建议就医", systemImage: "thermometer.high")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
              DismissingToggle(title: "症状持续中", isOn: $isContinuous)
            }

            Section("备注") {
                TextField("选填", text: $note, axis: .vertical).lineLimit(3...6)
            }

            Section {
                Button("保存记录") { save() }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(isHighRisk ? Color.red : Color.pink)
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        var types = Array(selectedTypes)
        if !customType.isEmpty { types.append(customType) }
        let payload = SymptomPayload(
            types: types,
            severity: severity,
            isContinuous: isContinuous,
            temperatureCelsius: Double(tempText),
            isHighRisk: isHighRisk
        )
        onSave(BabyEvent(babyId: baby.id, label: .symptom, startTime: time, note: note, payload: .symptom(payload)))
    }
}
