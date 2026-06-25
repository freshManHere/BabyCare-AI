import SwiftUI

struct FeedingFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time = Date()
    @State private var method: FeedingPayload.FeedingMethod = .directBreastfeeding
    @State private var amountText = ""
    @State private var leftBreastText = ""
    @State private var rightBreastText = ""
    @State private var wasBurped = false
    @State private var hadSpitUp = false
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                DatePicker("时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
            }

            Section("喂养方式") {
                Picker("方式", selection: $method) {
                    ForEach(FeedingPayload.FeedingMethod.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Duration fields: shown for 亲喂 and 混合
            if method.needsDuration {
                Section("哺乳时长") {
                    HStack {
                        Image(systemName: "l.circle.fill").foregroundStyle(.pink)
                        Text("左乳")
                        Spacer()
                        TextField("分钟", text: $leftBreastText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("分钟").foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "r.circle.fill").foregroundStyle(.purple)
                        Text("右乳")
                        Spacer()
                        TextField("分钟", text: $rightBreastText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("分钟").foregroundStyle(.secondary)
                    }
                }
            }

            // Amount field: shown for 母乳（瓶喂）、奶粉 and 混合
            if method.needsAmount {
                Section(method == .mixed ? "补充奶量（ml）" : "奶量（ml）") {
                    TextField("请输入", text: $amountText)
                        .keyboardType(.numberPad)
                }
            }

            Section("其他") {
                Toggle("是否拍嗝", isOn: $wasBurped)
                Toggle("是否吐奶", isOn: $hadSpitUp)
            }

            Section("备注") {
                TextField("选填", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button("保存") { save() }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(Color.pink)
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        let left = Int(leftBreastText)
        let right = Int(rightBreastText)
        let total = (left ?? 0) + (right ?? 0)
        let payload = FeedingPayload(
            method: method,
            amountMl: Int(amountText),
            durationMinutes: total > 0 ? total : nil,
            leftBreastMinutes: left,
            rightBreastMinutes: right,
            wasBurped: wasBurped,
            hadSpitUp: hadSpitUp
        )
        let event = BabyEvent(
            babyId: baby.id,
            label: .feeding,
            startTime: time,
            note: note,
            payload: .feeding(payload)
        )
        onSave(event)
    }
}
