import Foundation

struct GrowthRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var babyId: UUID
    /// Normalized to start-of-day so same-day upsert works correctly.
    var date: Date
    var heightCm: Double?
    var weightKg: Double?
    /// Last local/server modification time — used to resolve multi-device conflicts (newer wins).
    var updatedAt: Date = Date()

    init(id: UUID = UUID(), babyId: UUID, date: Date, heightCm: Double? = nil, weightKg: Double? = nil, updatedAt: Date = Date()) {
        self.id = id
        self.babyId = babyId
        self.date = date
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, babyId, date, heightCm, weightKg, updatedAt
    }

    // Custom decode so locally-persisted JSON from before `updatedAt` existed
    // (missing the key entirely) still decodes instead of silently wiping the store.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        babyId = try c.decode(UUID.self, forKey: .babyId)
        date = try c.decode(Date.self, forKey: .date)
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(babyId, forKey: .babyId)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(heightCm, forKey: .heightCm)
        try c.encodeIfPresent(weightKg, forKey: .weightKg)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    /// Display label for the date.
    var dateLabel: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
