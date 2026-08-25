import SwiftUI

struct AddGrowthView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var store = GrowthStore.shared

    private let editingRecord: GrowthRecord?

    @State private var date: Date
    @State private var heightText: String
    @State private var weightText: String
    @State private var showingDeleteConfirm = false

    init(editingRecord: GrowthRecord? = nil) {
        self.editingRecord = editingRecord
        _date = State(initialValue: editingRecord?.date ?? Calendar.current.startOfDay(for: Date()))
        _heightText = State(initialValue: editingRecord?.heightCm.map { String(format: "%g", $0) } ?? "")
        _weightText = State(initialValue: editingRecord?.weightKg.map { String(format: "%g", $0) } ?? "")
    }

    private var heightCm: Double? { Double(heightText.trimmingCharacters(in: .whitespaces)) }
    private var weightKg: Double? { Double(weightText.trimmingCharacters(in: .whitespaces)) }
    private var canSave: Bool { heightCm != nil || weightKg != nil }
    private var isEditing: Bool { editingRecord != nil }

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

                if isEditing {
                    Section {
                        Button("删除记录", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑记录" : "记录身高体重")
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
            .confirmationDialog("确定要删除这条记录吗？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) { deleteRecord() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        if let editingRecord {
            var updated = editingRecord
            updated.date = date
            updated.heightCm = heightCm
            updated.weightKg = weightKg
            store.update(updated)
        } else {
            let record = GrowthRecord(
                babyId: baby.id,
                date: date,
                heightCm: heightCm,
                weightKg: weightKg
            )
            store.upsert(record)
        }
        dismiss()
    }

    private func deleteRecord() {
        guard let editingRecord else { return }
        store.delete(editingRecord)
        dismiss()
    }
}

#Preview {
    AddGrowthView()
        .environmentObject(AppState())
}
