import SwiftUI

struct DiaperChangeFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time: Date
    @State private var reason: DiaperChangePayload.ChangeReason
    @State private var urineAmount: DiaperChangePayload.UrineAmount
    @State private var hadPoop: Bool
    @State private var hasDiaperRash: Bool
    @State private var skinNote: String
    @State private var note: String

    private let existingEvent: BabyEvent?

    init(existingEvent: BabyEvent? = nil, onSave: @escaping (BabyEvent) -> Void) {
        self.existingEvent = existingEvent
        self.onSave = onSave
        if let event = existingEvent, case .diaperChange(let p) = event.payload {
            _time         = State(initialValue: event.startTime)
            _reason       = State(initialValue: p.reason)
            _urineAmount  = State(initialValue: p.urineAmount)
            _hadPoop      = State(initialValue: p.hadPoop)
            _hasDiaperRash = State(initialValue: p.hasDiaperRash)
            _skinNote     = State(initialValue: p.skinNote)
            _note         = State(initialValue: event.note)
        } else {
            _time         = State(initialValue: Date())
            _reason       = State(initialValue: .wet)
            _urineAmount  = State(initialValue: .medium)
            _hadPoop      = State(initialValue: false)
            _hasDiaperRash = State(initialValue: false)
            _skinNote     = State(initialValue: "")
            _note         = State(initialValue: "")
        }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("更换时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
            }

            Section("更换原因") {
                Picker("原因", selection: $reason) {
                    ForEach(DiaperChangePayload.ChangeReason.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("尿量") {
                Picker("尿量", selection: $urineAmount) {
                    ForEach(DiaperChangePayload.UrineAmount.allCases, id: \.self) { a in
                        Text(a.rawValue).tag(a)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("皮肤状况") {
              DismissingToggle(title: "是否有便便", isOn: $hadPoop)
              DismissingToggle(title: "是否有尿布疹", isOn: $hasDiaperRash)
                if hasDiaperRash {
                    TextField("皮肤状态备注", text: $skinNote)
                }
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
        let payload = DiaperChangePayload(
            reason: reason,
            urineAmount: urineAmount,
            hadPoop: hadPoop,
            hasDiaperRash: hasDiaperRash,
            skinNote: skinNote
        )
        if var updated = existingEvent {
            updated.startTime = time
            updated.note = note
            updated.payload = .diaperChange(payload)
            onSave(updated)
        } else {
            let event = BabyEvent(
                babyId: baby.id,
                label: .diaperChange,
                startTime: time,
                note: note,
                payload: .diaperChange(payload)
            )
            onSave(event)
        }
    }
}
