import Foundation
import Observation

@MainActor
@Observable
final class GrowthStore {
    static let shared = GrowthStore()

    private(set) var records: [GrowthRecord] = []

    private static var saveURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("growth_records.json")
    }

    private init() { load() }

    // MARK: - Upsert (same-day overwrite)
    func upsert(_ record: GrowthRecord) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: record.date)
        if let idx = records.firstIndex(where: {
            $0.babyId == record.babyId && cal.startOfDay(for: $0.date) == day
        }) {
            var updated = records[idx]
            updated.date = day
            if let h = record.heightCm { updated.heightCm = h }
            if let w = record.weightKg { updated.weightKg = w }
            records[idx] = updated
        } else {
            var new = record
            new.date = day
            records.append(new)
        }
        save()
    }

    func delete(_ record: GrowthRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    // MARK: - Query
    func records(for babyId: UUID, from start: Date, to end: Date) -> [GrowthRecord] {
        records
            .filter { $0.babyId == babyId && $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Persistence
    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: Self.saveURL, options: .atomic)
    }

    private func load() {
        guard
            FileManager.default.fileExists(atPath: Self.saveURL.path),
            let data = try? Data(contentsOf: Self.saveURL),
            let decoded = try? JSONDecoder().decode([GrowthRecord].self, from: data)
        else { return }
        records = decoded
    }
}
