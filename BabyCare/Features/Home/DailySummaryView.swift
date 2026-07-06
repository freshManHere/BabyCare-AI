import SwiftUI

// MARK: - #5 今日摘要 Sheet
struct DailySummaryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var store = EventStore.shared

    private var baby: Baby? { appState.currentBaby }

    private var feedingEvents: [BabyEvent] {
        guard let baby else { return [] }
        return store.events(for: .feeding, babyId: baby.id)
    }
    private var sleepEvents: [BabyEvent] {
        guard let baby else { return [] }
        return store.events(for: .sleep, babyId: baby.id)
    }
    private var diaperChangeEvents: [BabyEvent] {
        guard let baby else { return [] }
        return store.events(for: .diaperChange, babyId: baby.id)
    }
    private var allTodayEvents: [BabyEvent] {
        guard let baby else { return [] }
        return store.eventsForToday(babyId: baby.id)
    }

    var body: some View {
        NavigationStack {
            List {
                // Date header
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Date(), format: .dateTime.year().month().day())
                                .font(.title3.bold())
                            Text("今日摘要 · 共\(allTodayEvents.count)条记录")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("👶")
                            .font(.system(size: 36))
                    }
                    .padding(.vertical, 4)
                }

                // Feeding summary
                Section {
                    feedingSummaryContent
                } header: {
                    Label("喂养", systemImage: "drop.fill")
                }

                // Sleep summary
                Section {
                    sleepSummaryContent
                } header: {
                    Label("睡眠", systemImage: "moon.fill")
                }

                // Diaper summary
                Section {
                    diaperSummaryContent
                } header: {
                    Label("尿不湿更换", systemImage: "heart.fill")
                }

                // Other events
                let otherLabels: [EventLabel] = [.outing, .bath, .motorSkill, .symptom, .other]
                let otherEvents = allTodayEvents.filter { otherLabels.contains($0.label) }
                if !otherEvents.isEmpty {
                    Section {
                        ForEach(otherEvents) { event in
                            HStack(spacing: 10) {
                                Image(systemName: event.label.icon)
                                    .foregroundStyle(.pink)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.label.rawValue)
                                        .font(.subheadline.bold())
                                    Text(event.shortDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(event.startTime, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Label("其他记录", systemImage: "list.bullet.clipboard")
                    }
                }

                // Disclaimer
                Section {
                    Text("以上摘要仅供参考，不构成医疗建议。如有疑虑请咨询专业医生。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("今日摘要")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - Feeding Content
    @ViewBuilder
    private var feedingSummaryContent: some View {
        if feedingEvents.isEmpty {
            Text("今日暂无喂养记录")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            let summary = store.feedingSummary(babyId: baby!.id)
            SummaryStatRow(label: "喂养次数", value: "\(feedingEvents.count) 次")
            if summary.hasBottle {
                SummaryStatRow(label: "瓶喂总量", value: "\(summary.bottleMl) ml")
            }
            if summary.hasBreast {
                SummaryStatRow(label: "亲喂时长", value: "\(summary.breastMinutes) 分钟")
            }
            if let first = feedingEvents.last, let last = feedingEvents.first {
                SummaryStatRow(
                    label: "时间范围",
                    value: "\(first.startTime.formatted(.dateTime.hour().minute())) — \(last.startTime.formatted(.dateTime.hour().minute()))"
                )
            }
            let methodCounts = Dictionary(grouping: feedingEvents) { event -> String in
                if case .feeding(let p) = event.payload { return p.method.rawValue }
                return "未知"
            }.mapValues { $0.count }
            ForEach(methodCounts.sorted(by: { $0.key < $1.key }), id: \.key) { method, count in
                SummaryStatRow(label: method, value: "\(count) 次", tint: .pink)
            }
        }
    }

    // MARK: - Sleep Content
    @ViewBuilder
    private var sleepSummaryContent: some View {
        if sleepEvents.isEmpty {
            Text("今日暂无睡眠记录")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            let totalMins = store.totalSleepMinutes(babyId: baby!.id)
            SummaryStatRow(label: "睡眠次数", value: "\(sleepEvents.count) 次")
            if totalMins > 0 {
                let h = totalMins / 60
                let m = totalMins % 60
                let displayText = h > 0 ? "\(h)小时\(m > 0 ? "\(m)分钟" : "")" : "\(m)分钟"
                SummaryStatRow(label: "累计睡眠", value: displayText)

                // Reference range
                let ageMonths = baby?.ageInMonths ?? 0
                let recommended = ageMonths < 4 ? "14-17小时" : (ageMonths < 12 ? "12-15小时" : "11-14小时")
                SummaryStatRow(label: "参考范围（每日）", value: recommended, tint: .secondary)
            }
            let inProgress = sleepEvents.filter { $0.endTime == nil }
            if !inProgress.isEmpty {
                SummaryStatRow(label: "进行中", value: "睡眠中 💤", tint: .blue)
            }
        }
    }

    // MARK: - Diaper Content
    @ViewBuilder
    private var diaperSummaryContent: some View {
        if diaperChangeEvents.isEmpty {
            Text("今日暂无尿不湿更换记录")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            SummaryStatRow(label: "更换次数", value: "\(diaperChangeEvents.count) 次")
            let rashCount = diaperChangeEvents.filter {
                if case .diaperChange(let p) = $0.payload { return p.hasDiaperRash }
                return false
            }.count
            if rashCount > 0 {
                SummaryStatRow(label: "⚠️ 发现尿布疹", value: "\(rashCount) 次", tint: .orange)
            }
            let reasonCounts = Dictionary(grouping: diaperChangeEvents) { event -> String in
                if case .diaperChange(let p) = event.payload { return p.reason.rawValue }
                return "其他"
            }.mapValues { $0.count }
            ForEach(reasonCounts.sorted(by: { $0.key < $1.key }), id: \.key) { reason, count in
                SummaryStatRow(label: reason, value: "\(count) 次", tint: .pink)
            }
        }
    }
}

// MARK: - Summary Stat Row
struct SummaryStatRow: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    DailySummaryView()
        .environmentObject(AppState())
}
