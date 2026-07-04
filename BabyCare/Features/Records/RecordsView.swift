import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @State private var selectedLabel: EventLabel? = nil
    /// Shared time range — driven by the chart's segment picker when a label tab is selected.
    @State private var trendTimeRange: TrendTimeRange = .week
    @State private var showingAddRecord = false
    @State private var filterScrollProxy: ScrollViewProxy? = nil
    @State private var navigationPath = NavigationPath()

    private var baby: Baby? { appState.currentBaby }

    /// Events for the current period + label filter, sorted newest first.
    /// When no label is selected (no chart), defaults to today's events.
    private var filteredEvents: [BabyEvent] {
        guard let baby else { return [] }
        if selectedLabel != nil {
            // Use the chart's time range
            let (start, end) = trendTimeRange.listDateRange
            return store.events(babyId: baby.id, from: start, to: end)
                .filter { $0.label == selectedLabel! }
                .sorted { $0.startTime > $1.startTime }
        } else {
            // No label selected — show today
            return store.eventsForToday(babyId: baby.id)
        }
    }

    /// Events grouped by calendar day, used for non-today periods.
    private var eventsByDay: [(date: Date, events: [BabyEvent])] {
        let cal = Calendar.current
        var groups: [Date: [BabyEvent]] = [:]
        for event in filteredEvents {
            let day = cal.startOfDay(for: event.startTime)
            groups[day, default: []].append(event)
        }
        return groups
            .map { (date: $0.key, events: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                labelFilterBar
                Divider()
                // Show trend chart when a specific label is selected (#26)
                if let label = selectedLabel {
                    ScrollView {
                        VStack(spacing: 0) {
                            LabelTrendChartView(label: label, timeRange: $trendTimeRange)
                                .environmentObject(appState)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            Divider()
                            lazyTimelineList
                        }
                    }
                } else {
                    groupedTimelineList
                }
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
                AddRecordView(preselectedLabel: selectedLabel)
                    .environmentObject(appState)
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
            // Bug #49 fix: reset navigation stack when switching away from records tab
            .onChange(of: appState.selectedTab) { _, tab in
                if tab != .records {
                    navigationPath = NavigationPath()
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

    // MARK: - Timeline List (with own scroll, used when no label selected)
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

    // MARK: - Grouped timeline list (non-today periods)
    private var groupedTimelineList: some View {
        Group {
            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "tray",
                    description: Text("该时间段内没有记录")
                )
            } else {
                List {
                    ForEach(eventsByDay, id: \.date) { group in
                        Section(header: dayHeader(group.date)) {
                            ForEach(group.events) { event in
                                NavigationLink {
                                    EventDetailView(event: event)
                                } label: {
                                    EventRowView(event: event)
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    store.delete(group.events[index])
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func dayHeader(_ date: Date) -> some View {
        let cal = Calendar.current
        let label: String
        if cal.isDateInToday(date) {
            label = "今天"
        } else if cal.isDateInYesterday(date) {
            label = "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 EEEE"
            label = formatter.string(from: date)
        }
        return Text(label)
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
    }

    // MARK: - Lazy timeline (embedded inside outer ScrollView when chart is shown)
    // Groups events by date so headers are visible below the trend chart.
    private var lazyTimelineList: some View {
        Group {
            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "tray",
                    description: Text("点击右上角 + 添加第一条记录")
                )
                .frame(height: 200)
            } else {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(eventsByDay, id: \.date) { group in
                        Section {
                            ForEach(group.events) { event in
                                NavigationLink {
                                    EventDetailView(event: event)
                                } label: {
                                    EventRowView(event: event)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.delete(event)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                Divider().padding(.leading, 72)
                            }
                        } header: {
                            dayHeader(group.date)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color(.systemGroupedBackground))
                        }
                    }
                }
                .background(Color(.systemBackground))
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
