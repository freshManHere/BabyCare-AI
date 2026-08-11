import Foundation
import Observation

// MARK: - Event Store
@MainActor
@Observable
final class EventStore {
    var events: [BabyEvent] = []

    static let shared = EventStore()

    private static let saveURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("baby_events.json")
    }()

    private init() {
        load()
    }

    // MARK: - CRUD
    func add(_ event: BabyEvent) {
        events.append(event)
        events.sort { $0.startTime > $1.startTime }
        save()
        SyncManager.shared.enqueueEvent(event)
    }

    func delete(_ event: BabyEvent) {
        events.removeAll { $0.id == event.id }
        save()
        SyncManager.shared.enqueueDeleteEvent(babyId: event.babyId, eventId: event.id)
    }

    func update(_ event: BabyEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            events.sort { $0.startTime > $1.startTime }
            save()
            SyncManager.shared.enqueueEvent(event)
        }
    }

    /// Insert or update an event by id (used for sync merges)
    func upsert(_ event: BabyEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        events.sort { $0.startTime > $1.startTime }
        save()
    }

    func deleteAll() {
        events = []
        save()
    }

    // MARK: - Persistence
    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: Self.saveURL, options: .atomic)
        } catch {
            print("[EventStore] Save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.saveURL)
            events = try JSONDecoder().decode([BabyEvent].self, from: data)
            events.sort { $0.startTime > $1.startTime }
        } catch {
            print("[EventStore] Load failed: \(error)")
        }
    }

    // MARK: - Queries
    func eventsForToday(babyId: UUID) -> [BabyEvent] {
        let calendar = Calendar.current
        return events.filter {
            $0.babyId == babyId &&
            calendar.isDateInToday($0.startTime)
        }.sorted { $0.startTime > $1.startTime }
    }

    func events(for label: EventLabel, babyId: UUID) -> [BabyEvent] {
        eventsForToday(babyId: babyId).filter { $0.label == label }
    }

    func lastEvent(for label: EventLabel, babyId: UUID) -> BabyEvent? {
        events(for: label, babyId: babyId).first
    }

    /// Events for a given label within a date range
    func events(for label: EventLabel, babyId: UUID, from start: Date, to end: Date) -> [BabyEvent] {
        events.filter {
            $0.babyId == babyId &&
            $0.label == label &&
            $0.startTime >= start &&
            $0.startTime <= end
        }.sorted { $0.startTime < $1.startTime }
    }

    /// All events within a date range
    func events(babyId: UUID, from start: Date, to end: Date) -> [BabyEvent] {
        events.filter {
            $0.babyId == babyId &&
            $0.startTime >= start &&
            $0.startTime <= end
        }.sorted { $0.startTime < $1.startTime }
    }

    /// Total sleep duration in minutes for today
    func totalSleepMinutes(babyId: UUID) -> Int {
        events(for: .sleep, babyId: babyId).reduce(0) { total, event in
            guard let end = event.endTime else { return total }
            return total + Int(end.timeIntervalSince(event.startTime) / 60)
        }
    }

    /// Total feeding amount in ml for today (formula/mixed only)
    func totalFeedingAmountMl(babyId: UUID) -> Int {
        events(for: .feeding, babyId: babyId).reduce(0) { total, event in
            if case .feeding(let p) = event.payload { return total + (p.amountMl ?? 0) }
            return total
        }
    }

    // MARK: - Feeding summary (distinguishes bottle ml from breastfeeding minutes)
    struct FeedingSummary {
        /// Total ml from bottle-fed sessions (母乳瓶喂 / 奶粉 / 混合瓶补)
        let bottleMl: Int
        /// Total direct breastfeeding minutes (亲喂 + 混合亲喂部分)
        let breastMinutes: Int
        /// Total number of feeding sessions
        let count: Int

        var hasBottle: Bool { bottleMl > 0 }
        var hasBreast: Bool { breastMinutes > 0 }

        /// Human-readable secondary stat for display cards
        var secondaryStat: String {
            switch (hasBottle, hasBreast) {
            case (true, true):
                return "瓶\(bottleMl)ml · 亲\(breastMinutes)min"
            case (true, false):
                return "共\(bottleMl)ml"
            case (false, true):
                return "亲喂\(breastMinutes)min"
            case (false, false):
                return count > 0 ? "母乳" : "暂无记录"
            }
        }
    }

    func feedingSummary(babyId: UUID) -> FeedingSummary {
        let feedEvents = events(for: .feeding, babyId: babyId)
        var bottleMl = 0
        var breastMinutes = 0
        for event in feedEvents {
            guard case .feeding(let p) = event.payload else { continue }
            bottleMl += p.amountMl ?? 0
            breastMinutes += p.durationMinutes ?? 0
        }
        return FeedingSummary(bottleMl: bottleMl, breastMinutes: breastMinutes, count: feedEvents.count)
    }

    // MARK: - Alerts
    struct Alert: Identifiable {
        let id = UUID()
        let level: Level
        let title: String
        let subtitle: String
        let destination: AlertDestination

        enum Level { case red, yellow, blue }
        enum AlertDestination { case assistant, symptomDetail(BabyEvent) }
    }

    func alerts(babyId: UUID) -> [Alert] {
        var result: [Alert] = []
        let todayEvents = eventsForToday(babyId: babyId)

        // 🔴 Red flags: high-risk symptoms
        let highRiskSymptoms = todayEvents.filter {
            if case .symptom(let p) = $0.payload { return p.isHighRisk }
            return false
        }
        for event in highRiskSymptoms {
            result.append(Alert(
                level: .red,
                title: "高风险症状",
                subtitle: event.shortDescription,
                destination: .symptomDetail(event)
            ))
        }

        // 🟡 Watch: no feeding in last 4 hours
        let feedingEvents = events(for: .feeding, babyId: babyId)
        let lastFeedingTime = feedingEvents.first?.startTime
        if let last = lastFeedingTime {
            let hoursSince = Date().timeIntervalSince(last) / 3600
            if hoursSince >= 4 {
                result.append(Alert(
                    level: .yellow,
                    title: "喂养间隔过长",
                    subtitle: "距离上次喂养已超过 \(Int(hoursSince)) 小时",
                    destination: .assistant
                ))
            }
        } else if !Calendar.current.isDateInToday(Date(timeIntervalSinceNow: -3600)) {
            // No feeding at all today (only show if it's been a while since midnight)
        }

        // 🔵 Highlights: motor skill milestone
        let motorEvents = events(for: .motorSkill, babyId: babyId)
        if !motorEvents.isEmpty {
            result.append(Alert(
                level: .blue,
                title: "今日里程碑",
                subtitle: motorEvents.first!.shortDescription,
                destination: .assistant
            ))
        }

        return result
    }
}
