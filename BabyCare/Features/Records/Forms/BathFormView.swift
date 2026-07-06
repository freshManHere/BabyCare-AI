import SwiftUI

struct BathFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time = Date()
    @State private var waterTempText = "37"
    @State private var durationText = ""
    @State private var washedHair = false
    @State private var usedSkincare = false
    @State private var afterCondition = ""
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                DatePicker("洗澡时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
            }

            Section("洗澡详情") {
                HStack {
                    Text("水温")
                    Spacer()
                    TextField("°C", text: $waterTempText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("°C").foregroundStyle(.secondary)
                }
                HStack {
                    Text("时长")
                    Spacer()
                    TextField("分钟", text: $durationText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("分钟").foregroundStyle(.secondary)
                }
            }

            Section("护理") {
              DismissingToggle(title: "是否洗头", isOn: $washedHair)
              DismissingToggle(title: "使用了护肤品", isOn: $usedSkincare)
            }

            Section("洗后状态") {
                TextField("如：皮肤状态良好、有轻微红疹", text: $afterCondition)
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
        let payload = BathPayload(
            waterTempCelsius: Double(waterTempText),
            washedHair: washedHair,
            usedSkincare: usedSkincare,
            afterCondition: afterCondition
        )
        onSave(BabyEvent(babyId: baby.id, label: .bath, startTime: time, note: note, payload: .bath(payload)))
    }
}
