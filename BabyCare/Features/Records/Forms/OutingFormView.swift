import SwiftUI

struct OutingFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var departureTime = Date()
    @State private var returnTime = Date()
    @State private var hasReturnTime = false
    @State private var destination = ""
    @State private var transportation: OutingPayload.Transportation = .stroller
    @State private var afterFeeding = false
    @State private var note = ""

    var duration: String {
        guard hasReturnTime else { return "" }
        let mins = Int(returnTime.timeIntervalSince(departureTime) / 60)
        guard mins > 0 else { return "" }
        return mins >= 60 ? "\(mins/60)小时\(mins%60 > 0 ? "\(mins%60)分钟" : "")" : "\(mins)分钟"
    }

    var body: some View {
        Form {
            Section {
                DatePicker("出门时间", selection: $departureTime, displayedComponents: [.date, .hourAndMinute])
                Toggle("已返回", isOn: $hasReturnTime)
                if hasReturnTime {
                    DatePicker("返回时间", selection: $returnTime, in: departureTime..., displayedComponents: [.date, .hourAndMinute])
                    if !duration.isEmpty {
                        LabeledContent("外出时长", value: duration)
                    }
                }
            }

            Section("目的地") {
                TextField("去哪儿了（选填）", text: $destination)
            }

            Section("出行方式") {
                Picker("方式", selection: $transportation) {
                    ForEach(OutingPayload.Transportation.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                Toggle("喂奶后外出", isOn: $afterFeeding)
            }

            Section("备注") {
                TextField("选填", text: $note, axis: .vertical).lineLimit(3...6)
            }

            Section {
                Button("保存") { save() }
                    .frame(maxWidth: .infinity).foregroundStyle(.white).listRowBackground(Color.pink)
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        let payload = OutingPayload(destination: destination, transportation: transportation, afterFeeding: afterFeeding)
        onSave(BabyEvent(
            babyId: baby.id, label: .outing,
            startTime: departureTime,
            endTime: hasReturnTime ? returnTime : nil,
            note: note,
            payload: .outing(payload)
        ))
    }
}
