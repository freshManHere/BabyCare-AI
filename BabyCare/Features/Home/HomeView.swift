import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @State private var showingAddRecord = false
    @State private var quickAddLabel: EventLabel?

    private var baby: Baby? { appState.currentBaby }
    private var todayEvents: [BabyEvent] {
        guard let baby else { return [] }
        return store.eventsForToday(babyId: baby.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    babyHeaderSection
                    overviewSection
                    alertSection
                    quickActionsSection
                    summarySection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddRecord) {
                AddRecordView(preselectedLabel: quickAddLabel)
            }
        }
    }

    // MARK: - Baby Header
    private var babyHeaderSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.pink.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Text("👶")
                        .font(.system(size: 30))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(baby?.nickname ?? "添加宝宝")
                    .font(.title2.bold())
                Text(baby != nil ? "月龄 \(baby!.ageDescription)" : "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Date(), style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }

    // MARK: - Overview
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日概览")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(EventLabel.allCases.filter { $0 != .other }) { label in
                    OverviewCard(
                        label: label,
                        count: todayEvents.filter { $0.label == label }.count
                    )
                    .onTapGesture {
                        appState.switchToTab(.records)
                    }
                }
            }
        }
    }

    // MARK: - Alert
    private var alertSection: some View {
        let highRiskEvents = todayEvents.filter {
            if case .symptom(let p) = $0.payload { return p.isHighRisk }
            return false
        }
        return Group {
            if !highRiskEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("注意事项", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)

                    ForEach(highRiskEvents) { event in
                        HStack {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text("检测到高风险症状，建议咨询医生")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(16)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速记录")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(EventLabel.allCases) { label in
                    QuickActionButton(label: label) {
                        quickAddLabel = label
                        showingAddRecord = true
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary
    private var summarySection: some View {
        Button {
            // TODO: Show daily summary
        } label: {
            HStack {
                Image(systemName: "doc.text.fill")
                Text("查看今日摘要")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.primary)
        }
    }
}

// MARK: - Overview Card
struct OverviewCard: View {
    let label: EventLabel
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: label.icon)
                    .foregroundStyle(.pink)
                Spacer()
                Text("\(count)")
                    .font(.title2.bold())
                    .foregroundStyle(count > 0 ? .primary : .tertiary)
            }
            Text(label.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(count > 0 ? "今日\(count)次" : "暂无记录")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let label: EventLabel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: label.icon)
                    .font(.title3)
                    .foregroundStyle(.pink)
                    .frame(width: 44, height: 44)
                    .background(Color.pink.opacity(0.1))
                    .clipShape(Circle())
                Text(label.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
