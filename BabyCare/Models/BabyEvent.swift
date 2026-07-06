import Foundation

// MARK: - Event Label
enum EventLabel: String, Codable, CaseIterable, Identifiable {
    case feeding = "喂养"
    case sleep = "睡眠"
    case diaperChange = "尿不湿"
    case outing = "外出"
    case bath = "洗澡"
    case motorSkill = "大运动"
    case symptom = "症状"
    case other = "其他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .feeding: return "drop.fill"
        case .sleep: return "moon.fill"
        case .diaperChange: return "heart.fill"
        case .outing: return "figure.walk"
        case .bath: return "shower.fill"
        case .motorSkill: return "figure.roll"
        case .symptom: return "thermometer.medium"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .feeding: return "FeedingColor"
        case .sleep: return "SleepColor"
        case .diaperChange: return "DiaperChangeColor"
        case .outing: return "OutingColor"
        case .bath: return "BathColor"
        case .motorSkill: return "MotorSkillColor"
        case .symptom: return "SymptomColor"
        case .other: return "OtherColor"
        }
    }
}

// MARK: - Base Event
struct BabyEvent: Identifiable, Codable {
    var id: UUID = UUID()
    var babyId: UUID
    var label: EventLabel
    var startTime: Date
    var endTime: Date?
    var note: String = ""
    var payload: EventPayload
    var createdAt: Date = Date()
    /// Set by the backend for soft-deleted events returned via /sync
    var deletedAt: Date? = nil
}

// MARK: - Event Payload (Type-safe union)
enum EventPayload: Codable {
    case feeding(FeedingPayload)
    case sleep(SleepPayload)
    case diaperChange(DiaperChangePayload)
    case outing(OutingPayload)
    case bath(BathPayload)
    case motorSkill(MotorSkillPayload)
    case symptom(SymptomPayload)
    case other(String)
}

// MARK: - Feeding
struct FeedingPayload: Codable {
    var method: FeedingMethod = .directBreastfeeding
    /// Bottle amount in ml (used for formula / bottled breastmilk / mixed supplement)
    var amountMl: Int?
    /// Total nursing duration in minutes (used for directBreastfeeding / mixed)
    var durationMinutes: Int?
    /// Left breast minutes (optional detail for directBreastfeeding / mixed)
    var leftBreastMinutes: Int?
    /// Right breast minutes (optional detail for directBreastfeeding / mixed)
    var rightBreastMinutes: Int?
    var wasBurped: Bool = false
    var hadSpitUp: Bool = false

    enum FeedingMethod: String, Codable, CaseIterable {
        case directBreastfeeding = "亲喂"
        case breastfeeding = "母乳（瓶喂）"
        case formula = "奶粉"
        case mixed = "混合"

        var needsDuration: Bool {
            self == .directBreastfeeding || self == .mixed
        }
        var needsAmount: Bool {
            self == .breastfeeding || self == .formula || self == .mixed
        }
    }
}

// MARK: - Sleep
struct SleepPayload: Codable {
    var sleepType: SleepType = .daytime
    var soothingMethod: String = ""
    var quality: SleepQuality = .good

    enum SleepType: String, Codable, CaseIterable {
        case daytime = "白天小睡"
        case nighttime = "夜间睡眠"
    }

    enum SleepQuality: String, Codable, CaseIterable {
        case good = "好"
        case fair = "一般"
        case poor = "差"
    }
}

// MARK: - Diaper Change
struct DiaperChangePayload: Codable {
    var reason: ChangeReason = .wet
    var urineAmount: UrineAmount = .medium
    var hadPoop: Bool = false
    var hasDiaperRash: Bool = false
    var skinNote: String = ""

    enum ChangeReason: String, Codable, CaseIterable {
        case wet = "尿湿"
        case poop = "大便"
        case mixed = "混合"
        case other = "其他"
    }

    enum UrineAmount: String, Codable, CaseIterable {
        case small = "少量"
        case medium = "中量"
        case large = "大量"
    }
}

// MARK: - Outing
struct OutingPayload: Codable {
    var destination: String = ""
    var transportation: Transportation = .stroller
    var afterFeeding: Bool = false

    enum Transportation: String, Codable, CaseIterable {
        case stroller = "推车"
        case carrier = "背带"
        case carSeat = "汽车座椅"
        case other = "其他"
    }
}

// MARK: - Bath
struct BathPayload: Codable {
    var waterTempCelsius: Double?
    var washedHair: Bool = false
    var usedSkincare: Bool = false
    var afterCondition: String = ""
}

// MARK: - Motor Skill
struct MotorSkillPayload: Codable {
    var actionTypes: [ActionType] = []
    var succeeded: Bool = true

    enum ActionType: String, Codable, CaseIterable {
        case headUp = "抬头"
        case rollOver = "翻身"
        case tummyTime = "俯卧支撑"
        case kicking = "踢腿"
        case grasping = "抓握"
        case other = "其他"
    }
}

// MARK: - Symptom
struct SymptomPayload: Codable {
    var types: [String] = []
    var severity: Severity = .mild
    var isContinuous: Bool = false
    var temperatureCelsius: Double?
    var isHighRisk: Bool = false

    enum Severity: String, Codable, CaseIterable {
        case mild = "轻微"
        case moderate = "中等"
        case severe = "严重"
    }
}
