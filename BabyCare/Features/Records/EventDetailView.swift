import SwiftUI

struct EventDetailView: View {
    let event: BabyEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    LabeledContent("类型", value: event.label.rawValue)
                    LabeledContent("时间", value: event.startTime.formatted(date: .abbreviated, time: .shortened))
                    if let endTime = event.endTime {
                        LabeledContent("结束", value: endTime.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section("详情") {
                    Text(event.shortDescription)
                        .foregroundStyle(.secondary)
                }

                if !event.note.isEmpty {
                    Section("备注") {
                        Text(event.note)
                    }
                }
            }
            .navigationTitle(event.label.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
