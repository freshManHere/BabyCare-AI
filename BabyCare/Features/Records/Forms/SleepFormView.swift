import SwiftUI

struct SleepFormView: View {
    @EnvironmentObject private var appState: AppState
    let existingEvent: BabyEvent?
    let onSave: (BabyEvent) -> Void

    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var hasEndTime = false
    @State private var sleepType: SleepPayload.SleepType = .daytime
    @State private var soothingMethod = ""
    @State private var quality: SleepPayload.SleepQuality = .good
    @State private var note = ""

    init(existingEvent: BabyEvent? = nil, onSave: @escaping (BabyEvent) -> Void) {
        self.existingEvent = existingEvent
        self.onSave = onSave
        // Pre-fill from existing event if editing
        if let event = existingEvent,
           case .sleep(let p) = event.payload {
            _startTime = State(initialValue: event.startTime)
            _endTime = State(initialValue: event.endTime ?? Date())
            _hasEndTime = State(initialValue: event.endTime != nil)
            _sleepType = State(initialValue: p.sleepType)
            _soothingMethod = State(initialValue: p.soothingMethod)
            _quality = State(initialValue: p.quality)
            _note = State(initialValue: event.note)
        }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("开始时间", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                Toggle("已结束", isOn: $hasEndTime)
                if hasEndTime {
                    DatePicker("结束时间", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                }
            }

            Section("睡眠类型") {
                Picker("类型", selection: $sleepType) {
                    ForEach(SleepPayload.SleepType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                TextField("哄睡方式（如：抱睡、奶睡）", text: $soothingMethod)
                Picker("睡眠质量", selection: $quality) {
                    ForEach(SleepPayload.SleepQuality.allCases, id: \.self) { q in
                        Text(q.rawValue).tag(q)
                    }
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
        let payload = SleepPayload(sleepType: sleepType, soothingMethod: soothingMethod, quality: quality)
        var event = BabyEvent(
            babyId: baby.id,
            label: .sleep,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            note: note,
            payload: .sleep(payload)
        )
        // Preserve original ID if editing
        if let existing = existingEvent {
            event.id = existing.id
            event.createdAt = existing.createdAt
        }
        onSave(event)
    }
}
