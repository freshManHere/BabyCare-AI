import SwiftUI

struct MotorSkillFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var selectedActions: Set<MotorSkillPayload.ActionType>
    @State private var succeeded: Bool
    @State private var note: String

    private let existingEvent: BabyEvent?

    init(existingEvent: BabyEvent? = nil, onSave: @escaping (BabyEvent) -> Void) {
        self.existingEvent = existingEvent
        self.onSave = onSave
        if let event = existingEvent, case .motorSkill(let p) = event.payload {
            _time = State(initialValue: event.startTime)
            _hasEndTime = State(initialValue: event.endTime != nil)
            _endTime = State(initialValue: event.endTime ?? Date())
            _selectedActions = State(initialValue: Set(p.actionTypes))
            _succeeded = State(initialValue: p.succeeded)
            _note = State(initialValue: event.note)
        } else {
            _time = State(initialValue: Date())
            _hasEndTime = State(initialValue: false)
            _endTime = State(initialValue: Date())
            _selectedActions = State(initialValue: [])
            _succeeded = State(initialValue: true)
            _note = State(initialValue: "")
        }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("开始时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
              DismissingToggle(title: "已结束", isOn: $hasEndTime)
                if hasEndTime {
                    DatePicker("结束时间", selection: $endTime, in: time..., displayedComponents: [.date, .hourAndMinute])
                }
            }

            Section("动作类型（可多选）") {
                ForEach(MotorSkillPayload.ActionType.allCases, id: \.self) { action in
                    Button {
                        if selectedActions.contains(action) {
                            selectedActions.remove(action)
                        } else {
                            selectedActions.insert(action)
                        }
                    } label: {
                        HStack {
                            Text(action.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedActions.contains(action) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.pink)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
              DismissingToggle(title: "是否成功完成", isOn: $succeeded)
            }

            Section("观察备注") {
                TextField("描述宝宝的表现（选填）", text: $note, axis: .vertical).lineLimit(3...6)
            }

            Section {
                Button("保存") { save() }
                    .frame(maxWidth: .infinity).foregroundStyle(.white).listRowBackground(Color.pink)
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        let payload = MotorSkillPayload(actionTypes: Array(selectedActions), succeeded: succeeded)
        if var updated = existingEvent {
            updated.startTime = time
            updated.endTime = hasEndTime ? endTime : nil
            updated.note = note
            updated.payload = .motorSkill(payload)
            onSave(updated)
        } else {
            var event = BabyEvent(babyId: baby.id, label: .motorSkill, startTime: time, note: note, payload: .motorSkill(payload))
            event.endTime = hasEndTime ? endTime : nil
            onSave(event)
        }
    }
}
