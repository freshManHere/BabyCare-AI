import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @State private var selectedLabel: EventLabel? = nil
    @State private var showingAddRecord = false
    @State private var filterScrollProxy: ScrollViewProxy? = nil

    private var baby: Baby? { appState.currentBaby }

    private var filteredEvents: [BabyEvent] {
        guard let baby else { return [] }
        let todayEvents = store.eventsForToday(babyId: baby.id)
        if let label = selectedLabel {
            return todayEvents.filter { $0.label == label }
        }
        return todayEvents
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                labelFilterBar
                Divider()
                timelineList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("记录")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddRecord = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.pink)
                    }
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                AddRecordView(preselectedLabel: nil)
            }
            // Bug #25 fix: consume pending filter on appear (handles cold-start first tap)
            .onAppear {
                if let filter = appState.pendingRecordsFilter {
                    selectedLabel = filter
                    appState.pendingRecordsFilter = nil
                    DispatchQueue.main.async {
                        withAnimation {
                            filterScrollProxy?.scrollTo(filter.id, anchor: .center)
                        }
                    }
                }
            }
            // Bug #22 fix: apply label filter passed from HomeView overview card tap
            .onChange(of: appState.pendingRecordsFilter) { _, newFilter in
                if let filter = newFilter {
                    selectedLabel = filter
                    appState.pendingRecordsFilter = nil
                    // Auto-scroll the filter bar to the selected chip
                    DispatchQueue.main.async {
                        withAnimation {
                            filterScrollProxy?.scrollTo(filter.id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Label Filter Bar
    private var labelFilterBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "全部", isSelected: selectedLabel == nil) {
                        selectedLabel = nil
                    }
                    .id("all")
                    ForEach(EventLabel.allCases) { label in
                        FilterChip(
                            title: label.rawValue,
                            icon: label.icon,
                            isSelected: selectedLabel == label
                        ) {
                            selectedLabel = (selectedLabel == label) ? nil : label
                            withAnimation {
                                if let sel = selectedLabel {
                                    proxy.scrollTo(sel.id, anchor: .center)
                                } else {
                                    proxy.scrollTo("all", anchor: .center)
                                }
                            }
                        }
                        .id(label.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(.systemBackground))
            .onAppear { filterScrollProxy = proxy }
        }
    }

    // MARK: - Timeline List
    private var timelineList: some View {
        Group {
            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "tray",
                    description: Text("点击右上角 + 添加第一条记录")
                )
            } else {
                List {
                    ForEach(filteredEvents) { event in
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            EventRowView(event: event)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.delete(filteredEvents[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.pink : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Row
struct EventRowView: View {
    let event: BabyEvent

    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(spacing: 2) {
                Text(event.startTime, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color.pink.opacity(0.3))
                    .frame(width: 1)
            }
            .frame(width: 44)

            // Icon
            Image(systemName: event.label.icon)
                .font(.title3)
                .foregroundStyle(.pink)
                .frame(width: 36, height: 36)
                .background(Color.pink.opacity(0.1))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.label.rawValue)
                    .font(.subheadline.bold())
                Text(event.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RecordsView()
        .environmentObject(AppState())
}
