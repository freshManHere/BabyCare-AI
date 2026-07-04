import SwiftUI

struct OutingFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var departureTime: Date
    @State private var returnTime: Date
    @State private var hasReturnTime: Bool
    @State private var destination: String
    @State private var transportation: OutingPayload.Transportation
    @State private var afterFeeding: Bool
    @State private var note: String

    private let existingEvent: BabyEvent?

    init(existingEvent: BabyEvent? = nil, onSave: @escaping (BabyEvent) -> Void) {
        self.existingEvent = existingEvent
        self.onSave = onSave
        if let event = existingEvent, case .outing(let p) = event.payload {
            _departureTime = State(initialValue: event.startTime)
            _hasReturnTime = State(initialValue: event.endTime != nil)
            _returnTime = State(initialValue: event.endTime ?? Date())
            _destination = State(initialValue: p.destination)
            _transportation = State(initialValue: p.transportation)
            _afterFeeding = State(initialValue: p.afterFeeding)
            _note = State(initialValue: event.note)
        } else {
            _departureTime = State(initialValue: Date())
            _returnTime = State(initialValue: Date())
            _hasReturnTime = State(initialValue: false)
            _destination = State(initialValue: "")
            _transportation = State(initialValue: .stroller)
            _afterFeeding = State(initialValue: false)
            _note = State(initialValue: "")
        }
    }

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
              DismissingToggle(title: "已返回", isOn: $hasReturnTime)
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
              DismissingToggle(title: "喂奶后外出", isOn: $afterFeeding)
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
        if var updated = existingEvent {
            updated.startTime = departureTime
            updated.endTime = hasReturnTime ? returnTime : nil
            updated.note = note
            updated.payload = .outing(payload)
            onSave(updated)
        } else {
            onSave(BabyEvent(
                babyId: baby.id, label: .outing,
                startTime: departureTime,
                endTime: hasReturnTime ? returnTime : nil,
                note: note,
                payload: .outing(payload)
            ))
        }
    }
}
