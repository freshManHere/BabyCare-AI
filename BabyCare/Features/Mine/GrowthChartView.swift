import SwiftUI
import Charts

// MARK: - Time Range
enum GrowthTimeRange: String, CaseIterable, Identifiable {
    case month1 = "近1月"
    case month3 = "近3月"
    case month6 = "近6月"
    var id: String { rawValue }

    var days: Int {
        switch self {
        case .month1: return 30
        case .month3: return 90
        case .month6: return 180
        }
    }
}

// MARK: - Metric
enum GrowthMetric: String, CaseIterable, Identifiable {
    case height = "身高"
    case weight = "体重"
    var id: String { rawValue }

    var unit: String { self == .height ? "cm" : "kg" }
    var icon: String { self == .height ? "ruler" : "scalemass" }
}

// MARK: - GrowthChartView
struct GrowthChartView: View {
    @EnvironmentObject private var appState: AppState
    @State private var store = GrowthStore.shared
    @State private var timeRange: GrowthTimeRange = .month3
    @State private var metric: GrowthMetric = .weight
    @State private var showingAdd = false

    private var baby: Baby? { appState.currentBaby }

    private var dateRange: (start: Date, end: Date) {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: now)!
        return (start, now)
    }

    private var chartData: [GrowthRecord] {
        guard let baby else { return [] }
        let (start, end) = dateRange
        return store.records(for: baby.id, from: start, to: end)
            .filter { metric == .height ? $0.heightCm != nil : $0.weightKg != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Metric picker
                    Picker("指标", selection: $metric) {
                        ForEach(GrowthMetric.allCases) { m in
                            Label(m.rawValue, systemImage: m.icon).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Time range picker
                    Picker("时间范围", selection: $timeRange) {
                        ForEach(GrowthTimeRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Chart
                    chartCard

                    // Records list
                    recordsList
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("生长记录")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.pink)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddGrowthView()
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - Chart Card
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(metric.rawValue)趋势（\(metric.unit)）")
                .font(.headline)
                .padding(.horizontal)

            if chartData.isEmpty {
                ContentUnavailableView(
                    "暂无数据",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("点击右上角 + 添加\(metric.rawValue)记录")
                )
                .frame(height: 180)
            } else {
                Chart {
                    ForEach(chartData) { record in
                        let yVal = metric == .height
                            ? record.heightCm!
                            : record.weightKg!
                        LineMark(
                            x: .value("日期", record.date),
                            y: .value(metric.unit, yVal)
                        )
                        .foregroundStyle(Color.pink)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("日期", record.date),
                            y: .value(metric.unit, yVal)
                        )
                        .foregroundStyle(Color.pink)
                        .symbolSize(50)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxisLabel(metric.unit)
                .frame(height: 200)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Records List
    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("历史记录")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if chartData.isEmpty {
                Text("暂无记录")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(chartData.reversed()) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.dateLabel)
                                    .font(.subheadline.bold())
                                if metric == .height, let h = record.heightCm {
                                    Text(String(format: "%.1f cm", h))
                                        .font(.title3.bold())
                                        .foregroundStyle(.pink)
                                } else if metric == .weight, let w = record.weightKg {
                                    Text(String(format: "%.2f kg", w))
                                        .font(.title3.bold())
                                        .foregroundStyle(.pink)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        Divider().padding(.leading, 16)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    GrowthChartView()
        .environmentObject(AppState())
}
