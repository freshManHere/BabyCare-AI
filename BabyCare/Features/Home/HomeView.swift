import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @State private var quickAddLabel: EventLabel?
    @State private var showingSummary = false

    private var baby: Baby? { appState.currentBaby }
    private var todayEvents: [BabyEvent] {
        guard let baby else { return [] }
        return store.eventsForToday(babyId: baby.id)
    }
    private var activeAlerts: [EventStore.Alert] {
        guard let baby else { return [] }
        return store.alerts(babyId: baby.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    babyHeaderSection
                    if !activeAlerts.isEmpty {
                        alertSection
                    }
                    overviewSection
                    quickActionsSection
                    summaryEntrySection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $quickAddLabel) { label in
                AddRecordView(preselectedLabel: label)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingSummary) {
                DailySummaryView()
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - #2 Baby Header (宝宝头像、昵称、月龄、日期)
    private var babyHeaderSection: some View {
        // Bug #32 fix: make header tappable → navigate to 我的 tab to set up baby profile
        Button {
            appState.switchToTab(.mine)
        } label: {
            babyHeaderContent
        }
        .buttonStyle(.plain)
    }

    private var babyHeaderContent: some View {
        HStack(spacing: 14) {
            Group {
                if let data = baby?.avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay {
                            Text(baby?.gender == .female ? "👧" : "👶")
                                .font(.system(size: 32))
                        }
                }
            }
            .shadow(color: .pink.opacity(0.15), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(baby?.nickname ?? "点击设置宝宝信息")
                    .font(.title3.bold())
                HStack(spacing: 6) {
                    if let baby {
                        Label(baby.ageDescription, systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.pink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.pink.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Date(), format: .dateTime.month().day())
                    .font(.subheadline.bold())
                Text(Date(), format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.top, 8)
    }

    // MARK: - #2 Overview Section (今日概览 - 7类数据)
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日概览")
                    .font(.headline)
                Spacer()
                Text(todayEvents.isEmpty ? "暂无记录" : "共\(todayEvents.count)条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(EventLabel.allCases.filter { $0 != .other }) { label in
                    overviewCard(for: label)
                        .onTapGesture {
                            // Bug #22 fix: pass the label filter to RecordsView
                            appState.switchToRecords(filter: label)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func overviewCard(for label: EventLabel) -> some View {
        if let baby = appState.currentBaby {
            let labelEvents = store.events(for: label, babyId: baby.id)
            let count = labelEvents.count
            let lastTime = labelEvents.first?.startTime

            if label == .feeding {
                let total = store.totalFeedingAmountMl(babyId: baby.id)
                OverviewCard(
                    label: label,
                    primaryStat: count > 0 ? "\(count)次" : "—",
                    secondaryStat: total > 0 ? "共\(total)ml" : (count > 0 ? "母乳" : "暂无记录"),
                    lastTime: lastTime
                )
            } else if label == .sleep {
                let mins = store.totalSleepMinutes(babyId: baby.id)
                let h = mins / 60; let m = mins % 60
                let sleepText = mins > 0 ? (h > 0 ? "\(h)h\(m > 0 ? "\(m)m" : "")" : "\(m)m") : "—"
                OverviewCard(
                    label: label,
                    primaryStat: sleepText,
                    secondaryStat: count > 0 ? "共\(count)次" : "暂无记录",
                    lastTime: lastTime
                )
            } else {
                OverviewCard(
                    label: label,
                    primaryStat: count > 0 ? "\(count)次" : "—",
                    secondaryStat: count > 0 ? "今日记录" : "暂无记录",
                    lastTime: lastTime
                )
            }
        } else {
            OverviewCard(label: label, primaryStat: "—", secondaryStat: "暂无记录", lastTime: nil)
        }
    }

    // MARK: - #3 Alert Section (红旗/待观察/今日重点)
    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("提醒", systemImage: "bell.badge.fill")
                .font(.headline)

            VStack(spacing: 6) {
                ForEach(activeAlerts) { alert in
                    Button {
                        appState.switchToTab(.assistant)
                    } label: {
                        AlertRow(alert: alert)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - #4 Quick Actions (8种记录类型)
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速记录")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(EventLabel.allCases) { label in
                    QuickActionButton(label: label) {
                        quickAddLabel = label
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - #5 Summary Entry
    private var summaryEntrySection: some View {
        Button {
            showingSummary = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.pink)
                    .frame(width: 40, height: 40)
                    .background(Color.pink.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("查看今日摘要")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("喂养 · 睡眠 · 尿不湿 综合分析")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }
}

// MARK: - Overview Card
struct OverviewCard: View {
    let label: EventLabel
    let primaryStat: String
    let secondaryStat: String
    let lastTime: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: label.icon)
                    .font(.subheadline)
                    .foregroundStyle(.pink)
                    .frame(width: 28, height: 28)
                    .background(Color.pink.opacity(0.1))
                    .clipShape(Circle())
                Spacer()
                Text(primaryStat)
                    .font(.title3.bold())
                    .foregroundStyle(primaryStat == "—" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            }

            Text(label.rawValue)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack {
                Text(secondaryStat)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if let time = lastTime {
                    Text(time, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

// MARK: - Alert Row
struct AlertRow: View {
    let alert: EventStore.Alert

    private var levelColor: Color {
        switch alert.level {
        case .red: return .red
        case .yellow: return .orange
        case .blue: return .blue
        }
    }

    private var levelIcon: String {
        switch alert.level {
        case .red: return "exclamationmark.triangle.fill"
        case .yellow: return "eye.fill"
        case .blue: return "star.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: levelIcon)
                .font(.caption)
                .foregroundStyle(levelColor)
                .frame(width: 24, height: 24)
                .background(levelColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.title)
                    .font(.caption.bold())
                    .foregroundStyle(levelColor)
                Text(alert.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(levelColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let label: EventLabel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: label.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.pink)
                    .frame(width: 48, height: 48)
                    .background(Color.pink.opacity(0.1))
                    .clipShape(Circle())
                Text(label.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
