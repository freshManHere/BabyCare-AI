import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject private var appState: AppState
    let event: BabyEvent
    @Environment(\.dismiss) private var dismiss
    @State private var store = EventStore.shared
    @State private var showingEdit = false
    @State private var showingWakeConfirm = false
    @State private var showingDeleteConfirm = false

    private var isSleepInProgress: Bool {
        event.label == .sleep && event.endTime == nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    LabeledContent("类型", value: event.label.rawValue)
                    LabeledContent("开始", value: event.startTime.formatted(date: .abbreviated, time: .shortened))
                    if let endTime = event.endTime {
                        LabeledContent("结束", value: endTime.formatted(date: .abbreviated, time: .shortened))
                        let mins = Int(endTime.timeIntervalSince(event.startTime) / 60)
                        let h = mins / 60; let m = mins % 60
                        LabeledContent("时长", value: h > 0 ? "\(h)小时\(m > 0 ? "\(m)分钟" : "")" : "\(m)分钟")
                    } else if event.label == .sleep {
                        HStack {
                            Text("状态")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Label("进行中", systemImage: "moon.zzz.fill")
                                .foregroundStyle(.blue)
                                .font(.subheadline)
                        }
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

                // Quick "mark awake" button for in-progress sleep
                if isSleepInProgress {
                    Section {
                        Button {
                            showingWakeConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundStyle(.orange)
                                Text("标记睡醒（结束时间设为现在）")
                                    .foregroundStyle(.primary)
                            }
                        }

                        Button {
                            showingEdit = true
                        } label: {
                            HStack {
                                Image(systemName: "clock.badge.fill")
                                    .foregroundStyle(.pink)
                                Text("自定义结束时间")
                                    .foregroundStyle(.primary)
                            }
                        }
                    } header: {
                        Label("睡眠进行中", systemImage: "moon.fill")
                    }
                }
            }
            .navigationTitle(event.label.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingEdit = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                editSheet
            }
            .confirmationDialog(
                "将结束时间设为现在（\(Date().formatted(.dateTime.hour().minute()))）？",
                isPresented: $showingWakeConfirm,
                titleVisibility: .visible
            ) {
                Button("确认标记睡醒") {
                    var updated = event
                    updated.endTime = Date()
                    store.update(updated)
                    dismiss()
                }
            }
            .confirmationDialog(
                "删除这条记录？",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    store.delete(event)
                    dismiss()
                }
            } message: {
                Text("此操作不可撤销。")
            }
        }
    }

    @ViewBuilder
    private var editSheet: some View {
        if event.label == .sleep {
            NavigationStack {
                SleepFormView(existingEvent: event) { updated in
                    store.update(updated)
                    showingEdit = false
                    dismiss()
                }
                .environmentObject(appState)
                .navigationTitle("编辑睡眠记录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { showingEdit = false }
                    }
                }
            }
        } else if event.label == .feeding {
            NavigationStack {
                FeedingFormView(existingEvent: event) { updated in
                    store.update(updated)
                    showingEdit = false
                    dismiss()
                }
                .environmentObject(appState)
                .navigationTitle("编辑喂养记录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { showingEdit = false }
                    }
                }
            }
        } else if event.label == .motorSkill {
            NavigationStack {
                MotorSkillFormView(existingEvent: event) { updated in
                    store.update(updated)
                    showingEdit = false
                    dismiss()
                }
                .environmentObject(appState)
                .navigationTitle("编辑大运动记录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { showingEdit = false }
                    }
                }
            }
        } else if event.label == .outing {
            NavigationStack {
                OutingFormView(existingEvent: event) { updated in
                    store.update(updated)
                    showingEdit = false
                    dismiss()
                }
                .environmentObject(appState)
                .navigationTitle("编辑外出记录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { showingEdit = false }
                    }
                }
            }
        } else {
            // Generic edit: for now just show a read-only note about future support
            NavigationStack {
                Form {
                    Section {
                        Text("此类型记录的编辑功能即将推出。")
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("编辑记录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") { showingEdit = false }
                    }
                }
            }
        }
    }
}
