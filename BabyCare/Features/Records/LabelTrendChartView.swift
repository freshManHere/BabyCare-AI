import SwiftUI
import Charts

// MARK: - Time Range Picker
enum TrendTimeRange: String, CaseIterable, Identifiable {
    case today = "今天"
    case week = "近1周"
    case month = "近1月"
    case custom = "自定义"
    var id: String { rawValue }
}

// MARK: - Chart Data Point
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isHighRisk: Bool
}

// MARK: - Trend Chart View
struct LabelTrendChartView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = EventStore.shared
    @State private var timeRange: TrendTimeRange = .week
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false

    let label: EventLabel

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
            if dataPoints.isEmpty {
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
                    AxisMarks(values: .automatic(desiredCount: xAxisCount)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: xAxisFormat)
                    }
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
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        if timeRange == .today {
            // Feeding daily trend should reflect real feeding timestamps.
            return label == .feeding ? .dateTime.hour().minute() : .dateTime.hour()
        }
        return .dateTime.month(.abbreviated).day()
    }

    private var yAxisLabel: String {
        switch label {
        case .feeding: return "奶量(ml) / 次"
        case .sleep: return "时长(分钟)"
        case .diaperChange: return "次数"
        case .outing, .bath, .motorSkill, .symptom, .other: return "次数"
        }
    }

    // MARK: - Aggregation
    private func aggregated(events: [BabyEvent], start: Date, end: Date) -> [TrendDataPoint] {
        let cal = Calendar.current
        let isToday = timeRange == .today

        if isToday && label == .feeding {
            // For daily feeding trend, each record is plotted at its actual feeding time.
            return events
                .sorted { $0.startTime < $1.startTime }
                .map { event in
                    TrendDataPoint(
                        date: event.startTime,
                        value: metricValue(event),
                        isHighRisk: isHighRiskEvent(event)
                    )
                }
        }

        if isToday {
            // Group by hour
            var buckets: [Int: (value: Double, highRisk: Bool)] = [:]
            for event in events {
                let hour = cal.component(.hour, from: event.startTime)
                let val = metricValue(event)
                let hr = isHighRiskEvent(event)
                buckets[hour, default: (0, false)].value += val
                if hr { buckets[hour]?.highRisk = true }
            }
            return buckets.sorted { $0.key < $1.key }.map { (hour, data) in
                let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: start)!
                return TrendDataPoint(date: date, value: data.value, isHighRisk: data.highRisk)
            }
        } else {
            // Group by day
            var buckets: [Date: (value: Double, highRisk: Bool)] = [:]
            var cursor = start
            while cursor <= end {
                buckets[cursor] = (0, false)
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
            for event in events {
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
            // Show ml if available, else count as 1
            return Double(p.amountMl ?? (p.durationMinutes ?? 1))
        case .sleep(let p):
            guard let end = event.endTime else { return 0 }
            return Double(Int(end.timeIntervalSince(event.startTime) / 60))
        default:
            return 1
        }
    }

    private func isHighRiskEvent(_ event: BabyEvent) -> Bool {
        if case .symptom(let p) = event.payload { return p.isHighRisk }
        return false
    }
}
