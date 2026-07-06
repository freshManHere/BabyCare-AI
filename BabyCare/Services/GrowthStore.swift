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
    /// syncOnly: true when called from server pull — skips enqueue to avoid re-push loop
    func upsert(_ record: GrowthRecord, syncOnly: Bool = false) {
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
            if !syncOnly { SyncManager.shared.enqueueGrowthRecord(updated) }
        } else {
            var new = record
            new.date = day
            records.append(new)
            if !syncOnly { SyncManager.shared.enqueueGrowthRecord(new) }
        }
        save()
    }

    func delete(_ record: GrowthRecord) {
        records.removeAll { $0.id == record.id }
        save()
        SyncManager.shared.enqueueDeleteGrowthRecord(babyId: record.babyId, recordId: record.id)
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
