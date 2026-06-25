import Foundation
import Observation

// MARK: - Event Store
@MainActor
@Observable
final class EventStore {
    var events: [BabyEvent] = []

    static let shared = EventStore()

    private init() {
        loadSampleData()
    }

    // MARK: - CRUD
    func add(_ event: BabyEvent) {
        events.append(event)
        events.sort { $0.startTime > $1.startTime }
    }

    func delete(_ event: BabyEvent) {
        events.removeAll { $0.id == event.id }
    }

    func update(_ event: BabyEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            events.sort { $0.startTime > $1.startTime }
        }
    }

    // MARK: - Queries
    func eventsForToday(babyId: UUID) -> [BabyEvent] {
        let calendar = Calendar.current
        return events.filter {
            $0.babyId == babyId &&
            calendar.isDateInToday($0.startTime)
        }
    }

    func events(for label: EventLabel, babyId: UUID) -> [BabyEvent] {
        eventsForToday(babyId: babyId).filter { $0.label == label }
    }

    // MARK: - Sample Data
    private func loadSampleData() {
        let babyId = Baby.preview.id
        let now = Date()
        let calendar = Calendar.current

        events = [
            BabyEvent(
                babyId: babyId,
                label: .feeding,
                startTime: calendar.date(byAdding: .hour, value: -4, to: now)!,
                payload: .feeding(FeedingPayload(method: .breastfeeding, amountMl: 120, wasBurped: true))
            ),
            BabyEvent(
                babyId: babyId,
                label: .sleep,
                startTime: calendar.date(byAdding: .hour, value: -3, to: now)!,
                endTime: calendar.date(byAdding: .hour, value: -1, to: now),
                payload: .sleep(SleepPayload(sleepType: .daytime, quality: .good))
            ),
            BabyEvent(
                babyId: babyId,
                label: .diaperChange,
                startTime: calendar.date(byAdding: .hour, value: -2, to: now)!,
                payload: .diaperChange(DiaperChangePayload(reason: .wet, urineAmount: .medium))
            ),
        ]
    }
}
