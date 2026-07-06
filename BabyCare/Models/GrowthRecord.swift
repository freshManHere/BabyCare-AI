import Foundation

struct GrowthRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var babyId: UUID
    /// Normalized to start-of-day so same-day upsert works correctly.
    var date: Date
    var heightCm: Double?
    var weightKg: Double?

    /// Display label for the date.
    var dateLabel: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
