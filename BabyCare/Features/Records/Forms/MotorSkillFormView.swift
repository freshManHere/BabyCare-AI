import SwiftUI

struct MotorSkillFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time = Date()
    @State private var selectedActions: Set<MotorSkillPayload.ActionType> = []
    @State private var succeeded = true
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                DatePicker("记录时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
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
                Toggle("是否成功完成", isOn: $succeeded)
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
        onSave(BabyEvent(babyId: baby.id, label: .motorSkill, startTime: time, note: note, payload: .motorSkill(payload)))
    }
}
