import SwiftUI

struct FeedingFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time = Date()
    @State private var method: FeedingPayload.FeedingMethod = .breastfeeding
    @State private var amountText = ""
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

            Section("奶量 (ml)") {
                TextField("选填", text: $amountText)
                    .keyboardType(.numberPad)
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
                Button("保存") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .listRowBackground(Color.pink)
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        let amount = Int(amountText)
        let payload = FeedingPayload(
            method: method,
            amountMl: amount,
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
