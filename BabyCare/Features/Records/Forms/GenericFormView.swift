import SwiftUI

/// Generic fallback form for record types that don't have a dedicated form yet
struct GenericFormView: View {
    @EnvironmentObject private var appState: AppState
    let label: EventLabel
    let onSave: (BabyEvent) -> Void

    @State private var time = Date()
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                DatePicker("时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
            }

            Section("备注") {
                TextField("请输入\(label.rawValue)相关信息", text: $note, axis: .vertical)
                    .lineLimit(3...8)
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
        let event = BabyEvent(
            babyId: baby.id,
            label: label,
            startTime: time,
            note: note,
            payload: .other(note)
        )
        onSave(event)
    }
}
