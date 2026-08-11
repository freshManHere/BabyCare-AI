import SwiftUI
import Charts

// MARK: - Time Range Picker
enum TrendTimeRange: String, CaseIterable, Identifiable {
    case today = "今天"
    case week = "近1周"
    case month = "近1月"
    case custom = "自定义"
    var id: String { rawValue }

    /// Date range used to filter the records list below the chart.
    var listDateRange: (start: Date, end: Date) {
        let now = Date()
        let cal = Calendar.current
        switch self {
        case .today:
            return (cal.startOfDay(for: now), now)
        case .week:
            return (cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!, now)
        case .month:
            return (cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!, now)
        case .custom:
            // custom range is handled inside the chart view; fall back to week for the list
            return (cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!, now)
        }
    }
}

// MARK: - Chart Data Point
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isHighRisk: Bool
}

// MARK: - Combined Feeding Data Point
/// Holds both metrics for a single time point (or day bucket) so they can be
/// plotted side-by-side in the "综合" view without conflating their units.
struct FeedingComboPoint: Identifiable {
    let id = UUID()
    let date: Date
    let bottleMl: Double
    let breastMin: Double
}

// MARK: - Trend Chart View
struct LabelTrendChartView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @Binding var timeRange: TrendTimeRange
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false

    let label: EventLabel

    init(label: EventLabel, timeRange: Binding<TrendTimeRange>) {
        self.label = label
        self._timeRange = timeRange
    }

    private var dateRange: (start: Date, end: Date) {
        let now = Date()
        let cal = Calendar.current
        switch timeRange {
        case .today:
            return (cal.startOfDay(for: now), now)
        case .week:
            return (cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!, now)
        case .month:
            return (cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!, now)
        case .custom:
            return (cal.startOfDay(for: customStart), min(cal.date(byAdding: .day, value: 1, to: customEnd)!, now))
        }
    }

    private var dataPoints: [TrendDataPoint] {
        guard let baby = appState.currentBaby else { return [] }
        let (start, end) = dateRange
        let events = store.events(for: label, babyId: baby.id, from: start, to: end)
        return aggregated(events: events, start: start, end: end)
    }

    /// Used only by the feeding "综合" view: both bottle ml and breast minutes per point.
    private var comboDataPoints: [FeedingComboPoint] {
        guard let baby = appState.currentBaby else { return [] }
        let (start, end) = dateRange
        let events = store.events(for: label, babyId: baby.id, from: start, to: end)
        return aggregatedCombo(events: events, start: start, end: end)
    }

    /// A slightly widened version of `dateRange` used only for the chart's X scale.
    /// Data points sit exactly on `dateRange`'s edges, so without this buffer the
    /// first/last axis tick lands exactly at the plot's pixel boundary and its label
    /// (centered on the tick) gets clipped in half. Widening the scale — without
    /// changing which events are queried/plotted — pushes those ticks inward so
    /// their labels have room to render fully.
    private var xAxisDomain: ClosedRange<Date> {
        let (start, end) = dateRange
        let span = end.timeIntervalSince(start)
        let buffer = max(span * 0.06, 300) // at least 5 minutes
        return start.addingTimeInterval(-buffer)...end.addingTimeInterval(buffer)
    }

    /// Explicit, evenly-spaced tick dates for the line chart's X axis. `.automatic`
    /// tick selection snaps to "nice" calendar boundaries, which for a 7/30-day span
    /// can bunch several labels close together and still leave the very last one
    /// sitting exactly on the data's real end date (clipped by the plot edge).
    /// Spacing ticks evenly across the actual `dateRange` guarantees uniform gaps,
    /// and combined with the widened `xAxisDomain` above, the ticks never sit right
    /// on the plot's pixel boundary.
    private var xAxisTickDates: [Date] {
        let (start, end) = dateRange

        // For bath / motor-skill "近1月" charts: only label the first and last day,
        // plus any day with a zero value (so gaps in the routine are called out),
        // instead of a generic evenly-spaced set of ticks. Consecutive zero-value
        // days are thinned out (min gap) so their (now rotated) labels don't overlap.
        if (label == .bath || label == .motorSkill) && timeRange == .month {
            var candidates: Set<Date> = [start, end]
            for point in dataPoints where point.value == 0 {
                candidates.insert(point.date)
            }
            let sorted = candidates.sorted()
            let totalDays = max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1, 1)
            let maxLabels = 10
            let minGap = (Double(totalDays) / Double(maxLabels)) * 86400

            var kept: [Date] = []
            for (index, date) in sorted.enumerated() {
                let isEdge = index == 0 || index == sorted.count - 1
                if isEdge || kept.last.map({ date.timeIntervalSince($0) >= minGap }) ?? true {
                    kept.append(date)
                }
            }
            return kept
        }

        let count = max(xAxisCount, 2)
        let interval = end.timeIntervalSince(start) / Double(count - 1)
        return (0..<count).map { start.addingTimeInterval(interval * Double($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Time range picker
            HStack {
                Picker("时间范围", selection: $timeRange) {
                    ForEach(TrendTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Custom date pickers
            if timeRange == .custom {
                VStack(spacing: 6) {
                    DatePicker("开始", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                        .font(.caption)
                    DatePicker("结束", selection: $customEnd,
                               in: customStart...min(Calendar.current.date(byAdding: .day, value: 90, to: customStart)!, Date()),
                               displayedComponents: .date)
                        .font(.caption)
                }
                .padding(.horizontal, 4)
            }

            // Chart
            if label == .feeding {
                if comboDataPoints.isEmpty {
                    ContentUnavailableView(
                        "暂无数据",
                        systemImage: "chart.bar.xaxis",
                        description: Text("该时间段内没有喂养记录")
                    )
                    .frame(height: 160)
                } else {
                    combinedFeedingChart
                }
            } else if dataPoints.isEmpty {
                ContentUnavailableView(
                    "暂无数据",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("该时间段内没有\(label.rawValue)记录")
                )
                .frame(height: 160)
            } else {
                Chart {
                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value("时间", point.date),
                            y: .value(yAxisLabel, point.value)
                        )
                        .foregroundStyle(Color.pink)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("时间", point.date),
                            y: .value(yAxisLabel, point.value)
                        )
                        .foregroundStyle(point.isHighRisk ? Color.red : Color.pink)
                        .symbolSize(point.isHighRisk ? 80 : 40)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisTickDates) { value in
                        AxisGridLine()
                        // Rotated + smaller labels take much less horizontal room, so
                        // dense tick sets (e.g. every zero-value day in a month view)
                        // don't overlap each other.
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: xAxisFormat)
                                    .font(.system(size: 8))
                                    .fixedSize()
                                    .rotationEffect(.degrees(-45))
                                    .offset(y: 4)
                            }
                        }
                    }
                }
                .chartXScale(domain: xAxisDomain)
                .chartPlotStyle { plotArea in
                    // The domain edges sit exactly at the first/last data point, so the
                    // axis labels at those ticks (e.g. the rightmost time) would otherwise
                    // be clipped in half by the plot bounds. Reserve a little breathing
                    // room on both sides so every label renders fully.
                    plotArea.padding(.horizontal, 16)
                }
                .chartYAxisLabel(yAxisLabel)
                .frame(height: 180)
            }

            // Legend for high risk
            if label == .symptom && dataPoints.contains(where: { $0.isHighRisk }) {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("红点表示当日有高风险症状")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Legend for combined feeding view
            if label == .feeding {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.blue).frame(width: 10, height: 10)
                        Text("奶量(ml)").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.pink).frame(width: 10, height: 10)
                        Text("亲喂(min)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("柱高为相对比例，实际数值见标注")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Combined Feeding Chart
    /// Shows bottle ml and breastfeeding minutes together as normalized, color-coded
    /// bars, since the two metrics have incompatible units and Swift Charts has no
    /// native dual-Y-axis support. Each bar's height is capped below the top of the
    /// plot area so its value label always has room to render, and its timestamp is
    /// printed directly below it. When there are more bars than fit on screen, the
    /// chart scrolls horizontally instead of squeezing.
    private var combinedFeedingChart: some View {
        let points = comboDataPoints
        let maxBottle = points.map(\.bottleMl).max() ?? 0
        let maxBreast = points.map(\.breastMin).max() ?? 0
        let barWidth: CGFloat = 12
        let itemWidth: CGFloat = 58
        let contentWidth = CGFloat(points.count) * itemWidth
        // Bars never exceed this fraction of the plot's height, leaving guaranteed
        // headroom above the tallest bar for its value label.
        let maxBarRatio = 0.68
        // Bars with a positive value are never shorter than this, so their in-bar
        // label (rotated vertically to fit the narrow bar width) always has enough
        // room to render without spilling outside the bar.
        let minBarRatio = 0.32

        func barHeight(_ value: Double, max: Double) -> Double {
            guard max > 0, value > 0 else { return 0 }
            return Swift.max((value / max) * maxBarRatio, minBarRatio)
        }

        return GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("时间", point.date),
                            y: .value("相对比例", barHeight(point.bottleMl, max: maxBottle)),
                            width: .fixed(barWidth)
                        )
                        .position(by: .value("类型", "奶量"))
                        .foregroundStyle(Color.blue)
                        .cornerRadius(2)
                        .annotation(position: .overlay, alignment: .bottom) {
                            if point.bottleMl > 0 {
                                Text("\(Int(point.bottleMl))ml")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .rotationEffect(.degrees(-90))
                                    .padding(.bottom, 6)
                            }
                        }

                        BarMark(
                            x: .value("时间", point.date),
                            y: .value("相对比例", barHeight(point.breastMin, max: maxBreast)),
                            width: .fixed(barWidth)
                        )
                        .position(by: .value("类型", "亲喂"))
                        .foregroundStyle(Color.pink)
                        .cornerRadius(2)
                        .annotation(position: .overlay, alignment: .bottom) {
                            if point.breastMin > 0 {
                                Text("\(Int(point.breastMin))min")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .rotationEffect(.degrees(-90))
                                    .padding(.bottom, 6)
                            }
                        }
                    }
                }
                .chartXAxis {
                    // One label per data point, directly under its bars, instead of
                    // an automatic subset that may skip points.
                    AxisMarks(values: points.map(\.date)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: xAxisFormat)
                    }
                }
                .chartXScale(domain: dateRange.start...dateRange.end)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...1)
                .chartPlotStyle { plotArea in
                    // Reserve horizontal room so the first/last bar (whose center sits
                    // right on the domain edge) isn't clipped in half by the plot bounds.
                    plotArea.padding(.horizontal, barWidth * 1.5)
                }
                .frame(width: max(geo.size.width, contentWidth), height: geo.size.height)
            }
        }
        .frame(height: 190)
    }

    // MARK: - Axis helpers
    private var xAxisCount: Int {
        switch timeRange {
        case .today: return 6
        case .week: return 7
        case .month: return 6
        case .custom:
            let days = Calendar.current.dateComponents([.day], from: customStart, to: customEnd).day ?? 7
            return min(days + 1, 7)
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        // Today dimension always shows time (HH:mm); other ranges show date.
        return timeRange == .today ? .dateTime.hour().minute() : .dateTime.month(.abbreviated).day()
    }

    private var yAxisLabel: String {
        switch label {
        case .feeding: return ""
        case .sleep: return "时长(分钟)"
        case .diaperChange: return "次数"
        case .outing, .motorSkill: return "时长(分钟)"
        case .bath: return "次数"
        case .symptom, .other: return "次数"
        }
    }

    // MARK: - Aggregation
    /// Used for all non-feeding labels (feeding always uses the combined bar chart
    /// via `aggregatedCombo` instead).
    private func aggregated(events: [BabyEvent], start: Date, end: Date) -> [TrendDataPoint] {
        let cal = Calendar.current
        let isToday = timeRange == .today
        let relevantEvents = events

        if isToday {
            // Today: plot every event at its actual timestamp so the x-axis shows real times.
            return relevantEvents
                .sorted { $0.startTime < $1.startTime }
                .map { event in
                    TrendDataPoint(
                        date: event.startTime,
                        value: metricValue(event),
                        isHighRisk: isHighRiskEvent(event)
                    )
                }
        } else {
            // Group by day
            var buckets: [Date: (value: Double, highRisk: Bool)] = [:]
            var cursor = start
            while cursor <= end {
                buckets[cursor] = (0, false)
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
            for event in relevantEvents {
                let day = cal.startOfDay(for: event.startTime)
                let val = metricValue(event)
                let hr = isHighRiskEvent(event)
                buckets[day, default: (0, false)].value += val
                if hr { buckets[day]?.highRisk = true }
            }
            return buckets.sorted { $0.key < $1.key }.map { (date, data) in
                TrendDataPoint(date: date, value: data.value, isHighRisk: data.highRisk)
            }
        }
    }

    private func metricValue(_ event: BabyEvent) -> Double {
        switch event.payload {
        case .feeding(let p):
            // Not used for feeding anymore (combined bar chart uses aggregatedCombo),
            // kept for exhaustiveness of the generic single-metric path.
            return Double(p.amountMl ?? 0)
        case .sleep:
            guard let end = event.endTime else { return 0 }
            return Double(Int(end.timeIntervalSince(event.startTime) / 60))
        case .outing, .motorSkill:
            // Bug #42: show duration in minutes instead of count
            guard let end = event.endTime else { return 0 }
            return Double(Int(end.timeIntervalSince(event.startTime) / 60))
        case .bath:
            // Bath trend should be event count, not duration
            return 1
        default:
            return 1
        }
    }

    private func isHighRiskEvent(_ event: BabyEvent) -> Bool {
        if case .symptom(let p) = event.payload { return p.isHighRisk }
        return false
    }

    // MARK: - Combined Feeding Aggregation
    private func aggregatedCombo(events: [BabyEvent], start: Date, end: Date) -> [FeedingComboPoint] {
        let cal = Calendar.current
        let isToday = timeRange == .today

        func values(_ p: FeedingPayload) -> (bottle: Double, breast: Double) {
            let bottle = p.method.needsAmount ? Double(p.amountMl ?? 0) : 0
            let breast = p.method.needsDuration ? Double(p.durationMinutes ?? 0) : 0
            return (bottle, breast)
        }

        if isToday {
            return events
                .sorted { $0.startTime < $1.startTime }
                .compactMap { event -> FeedingComboPoint? in
                    guard case .feeding(let p) = event.payload else { return nil }
                    let (bottle, breast) = values(p)
                    return FeedingComboPoint(date: event.startTime, bottleMl: bottle, breastMin: breast)
                }
        } else {
            var buckets: [Date: (bottle: Double, breast: Double)] = [:]
            var cursor = start
            while cursor <= end {
                buckets[cursor] = (0, 0)
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
            for event in events {
                guard case .feeding(let p) = event.payload else { continue }
                let day = cal.startOfDay(for: event.startTime)
                let (bottle, breast) = values(p)
                buckets[day, default: (0, 0)].bottle += bottle
                buckets[day, default: (0, 0)].breast += breast
            }
            return buckets.sorted { $0.key < $1.key }.map { (date, data) in
                FeedingComboPoint(date: date, bottleMl: data.bottle, breastMin: data.breast)
            }
        }
    }
}
