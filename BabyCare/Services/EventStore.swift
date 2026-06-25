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
        }.sorted { $0.startTime > $1.startTime }
    }

    func events(for label: EventLabel, babyId: UUID) -> [BabyEvent] {
        eventsForToday(babyId: babyId).filter { $0.label == label }
    }

    func lastEvent(for label: EventLabel, babyId: UUID) -> BabyEvent? {
        events(for: label, babyId: babyId).first
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

        // 🟡 Watch: blood/mucus in diaper
        let abnormalDiaper = todayEvents.filter {
            if case .diaper(let p) = $0.payload { return p.hasBloodOrMucus || p.isAbnormal }
            return false
        }
        if !abnormalDiaper.isEmpty {
            result.append(Alert(
                level: .yellow,
                title: "排便异常",
                subtitle: "检测到血丝或黏液，建议关注",
                destination: .assistant
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

    // MARK: - Sample Data
    private func loadSampleData() {
        let babyId = Baby.preview.id
        let now = Date()
        let cal = Calendar.current

        events = [
            // Morning feedings
            BabyEvent(
                babyId: babyId, label: .feeding,
                startTime: cal.date(byAdding: .hour, value: -8, to: now)!,
                payload: .feeding(FeedingPayload(method: .breastfeeding, amountMl: 110, wasBurped: true, hadSpitUp: false))
            ),
            BabyEvent(
                babyId: babyId, label: .feeding,
                startTime: cal.date(byAdding: .hour, value: -5, to: now)!,
                payload: .feeding(FeedingPayload(method: .breastfeeding, amountMl: 130, wasBurped: true, hadSpitUp: false))
            ),
            BabyEvent(
                babyId: babyId, label: .feeding,
                startTime: cal.date(byAdding: .hour, value: -2, to: now)!,
                payload: .feeding(FeedingPayload(method: .formula, amountMl: 120, wasBurped: true, hadSpitUp: false))
            ),
            // Sleep
            BabyEvent(
                babyId: babyId, label: .sleep,
                startTime: cal.date(byAdding: .hour, value: -7, to: now)!,
                endTime: cal.date(byAdding: .hour, value: -5, to: now),
                payload: .sleep(SleepPayload(sleepType: .daytime, soothingMethod: "抱睡", quality: .good))
            ),
            BabyEvent(
                babyId: babyId, label: .sleep,
                startTime: cal.date(byAdding: .hour, value: -4, to: now)!,
                endTime: cal.date(byAdding: .minute, value: -90, to: now),
                payload: .sleep(SleepPayload(sleepType: .daytime, soothingMethod: "奶睡", quality: .fair))
            ),
            // Diaper changes
            BabyEvent(
                babyId: babyId, label: .diaperChange,
                startTime: cal.date(byAdding: .hour, value: -6, to: now)!,
                payload: .diaperChange(DiaperChangePayload(reason: .wet, urineAmount: .medium, hadPoop: false))
            ),
            BabyEvent(
                babyId: babyId, label: .diaperChange,
                startTime: cal.date(byAdding: .hour, value: -3, to: now)!,
                payload: .diaperChange(DiaperChangePayload(reason: .poop, urineAmount: .medium, hadPoop: true))
            ),
            // Bath
            BabyEvent(
                babyId: babyId, label: .bath,
                startTime: cal.date(byAdding: .hour, value: -1, to: now)!,
                payload: .bath(BathPayload(waterTempCelsius: 38.0, washedHair: true, usedSkincare: true, afterCondition: "皮肤状态良好"))
            ),
            // Motor skill milestone
            BabyEvent(
                babyId: babyId, label: .motorSkill,
                startTime: cal.date(byAdding: .minute, value: -30, to: now)!,
                payload: .motorSkill(MotorSkillPayload(actionTypes: [.headUp, .tummyTime], succeeded: true))
            ),
        ]
    }
}
