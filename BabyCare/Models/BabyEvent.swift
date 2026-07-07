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

    // MARK: Custom Codable
    // The server stores JSONB with snake_case keys coming from Swift's
    // convertToSnakeCase encoder (e.g. "motor_skill", "diaper_change").
    // convertFromSnakeCase on the decoder does NOT automatically map enum
    // discriminator keys, so we handle both forms manually here.
    private enum CodingKeys: String, CodingKey {
        case feeding
        case sleep
        case diaperChange, diaper_change
        case outing
        case bath
        case motorSkill, motor_skill
        case symptom
        case other
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.feeding) {
            self = .feeding(try container.decode(AssocWrapper<FeedingPayload>.self,   forKey: .feeding).value)
        } else if container.contains(.sleep) {
            self = .sleep(try container.decode(AssocWrapper<SleepPayload>.self,       forKey: .sleep).value)
        } else if container.contains(.diaperChange) {
            self = .diaperChange(try container.decode(AssocWrapper<DiaperChangePayload>.self, forKey: .diaperChange).value)
        } else if container.contains(.diaper_change) {
            self = .diaperChange(try container.decode(AssocWrapper<DiaperChangePayload>.self, forKey: .diaper_change).value)
        } else if container.contains(.outing) {
            self = .outing(try container.decode(AssocWrapper<OutingPayload>.self,     forKey: .outing).value)
        } else if container.contains(.bath) {
            self = .bath(try container.decode(AssocWrapper<BathPayload>.self,         forKey: .bath).value)
        } else if container.contains(.motorSkill) {
            self = .motorSkill(try container.decode(AssocWrapper<MotorSkillPayload>.self, forKey: .motorSkill).value)
        } else if container.contains(.motor_skill) {
            self = .motorSkill(try container.decode(AssocWrapper<MotorSkillPayload>.self, forKey: .motor_skill).value)
        } else if container.contains(.symptom) {
            self = .symptom(try container.decode(AssocWrapper<SymptomPayload>.self,   forKey: .symptom).value)
        } else if container.contains(.other) {
            self = .other(try container.decode(String.self, forKey: .other))
        } else {
            self = .other("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .feeding(let p):      try container.encode(AssocWrapper(p), forKey: .feeding)
        case .sleep(let p):        try container.encode(AssocWrapper(p), forKey: .sleep)
        case .diaperChange(let p): try container.encode(AssocWrapper(p), forKey: .diaperChange)
        case .outing(let p):       try container.encode(AssocWrapper(p), forKey: .outing)
        case .bath(let p):         try container.encode(AssocWrapper(p), forKey: .bath)
        case .motorSkill(let p):   try container.encode(AssocWrapper(p), forKey: .motorSkill)
        case .symptom(let p):      try container.encode(AssocWrapper(p), forKey: .symptom)
        case .other(let s):        try container.encode(s, forKey: .other)
        }
    }
}

/// Wraps an associated value as `{"_0": value}` to match Swift's default enum encoding.
private struct AssocWrapper<T: Codable>: Codable {
    let value: T
    enum CodingKeys: String, CodingKey { case _0 }
    init(_ value: T) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = try c.decode(T.self, forKey: ._0)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(value, forKey: ._0)
    }
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
