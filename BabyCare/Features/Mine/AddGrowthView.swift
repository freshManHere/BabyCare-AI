import SwiftUI

struct AddGrowthView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var store = GrowthStore.shared

    @State private var date: Date = Calendar.current.startOfDay(for: Date())
    @State private var heightText: String = ""
    @State private var weightText: String = ""

    private var heightCm: Double? { Double(heightText.trimmingCharacters(in: .whitespaces)) }
    private var weightKg: Double? { Double(weightText.trimmingCharacters(in: .whitespaces)) }
    private var canSave: Bool { heightCm != nil || weightKg != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("日期") {
                    DatePicker("记录日期", selection: $date,
                               in: ...Date(),
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section("身高") {
                    HStack {
                        TextField("例如 60.5", text: $heightText)
                            .keyboardType(.decimalPad)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }

                Section("体重") {
                    HStack {
                        TextField("例如 6.2", text: $weightText)
                            .keyboardType(.decimalPad)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("记录身高体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        let record = GrowthRecord(
            babyId: baby.id,
            date: date,
            heightCm: heightCm,
            weightKg: weightKg
        )
        store.upsert(record)
        dismiss()
    }
}

#Preview {
    AddGrowthView()
        .environmentObject(AppState())
}
