import SwiftUI

// MARK: - Weaning Calendar (辅食日历)
/// Month grid calendar highlighting days with weaning records, colored by allergy status.
struct WeaningCalendarView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDay: Date?
    let events: [BabyEvent]

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: displayedMonth)
    }

    private var eventsByDay: [Date: [BabyEvent]] {
        Dictionary(grouping: events) { calendar.startOfDay(for: $0.startTime) }
    }

    /// Full weeks grid, padded with adjacent-month days so every row has 7 cells.
    private var gridDays: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -leading, to: displayedMonth) else { return [] }
        let totalCells = Int(ceil(Double(leading + range.count) / 7.0)) * 7
        return (0..<totalCells).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthHeader

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(gridDays, id: \.self) { day in
                    dayCell(day)
                }
            }

            legend
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.pink)
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.pink)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let dayEvents = eventsByDay[calendar.startOfDay(for: day)] ?? []
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)

        return Button {
            selectedDay = isSelected ? nil : day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline)
                    .frame(width: 28, height: 28)
                    .background(isSelected ? Color.pink : Color.clear)
                    .foregroundStyle(isSelected ? Color.white : (inMonth ? Color.primary : Color.secondary.opacity(0.45)))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(isToday && !isSelected ? Color.pink : .clear, lineWidth: 1)
                    )

                if dayEvents.isEmpty {
                    Color.clear.frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(dotColor(for: dayEvents))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: .pink, title: "已记录")
            legendItem(color: .orange, title: "排敏中")
            legendItem(color: .green, title: "已排敏")
            legendItem(color: .red, title: "有反应")
        }
        .padding(.top, 2)
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func dotColor(for dayEvents: [BabyEvent]) -> Color {
        let payloads = dayEvents.compactMap { event -> WeaningPayload? in
            if case .weaning(let p) = event.payload { return p }
            return nil
        }
        if payloads.contains(where: { $0.reaction != .none }) { return .red }
        if payloads.contains(where: { $0.isAllergyCleared }) { return .green }
        if payloads.contains(where: { $0.isAllergyTesting }) { return .orange }
        return .pink
    }

    private func changeMonth(_ delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = newMonth
        selectedDay = nil
    }
}
