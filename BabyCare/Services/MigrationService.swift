import Foundation

// MARK: - Migration Service
// Uploads local JSON data to the backend once after first sign-in.
// Safe to call multiple times — a flag prevents re-migration.

@MainActor
final class MigrationService {

    private static let migratedKey = "local_data_migrated_v1"
    static var needsMigration: Bool {
        !UserDefaults.standard.bool(forKey: migratedKey)
    }

    private let syncService: any SyncService = RemoteSyncService()
    private let eventStore = EventStore.shared
    private let growthStore = GrowthStore.shared

    // MARK: - Progress state (for UI)
    @Published var progress: Double = 0
    @Published var statusMessage: String = ""
    @Published var isRunning = false
    @Published var error: String?

    func migrate(baby: Baby?) async {
        guard Self.needsMigration else { return }
        isRunning = true
        error = nil

        do {
            // Step 1: push baby profile
            if let baby {
                statusMessage = "上传宝宝档案…"
                progress = 0.1
                try await syncService.pushBaby(baby)
            }

            // Step 2: push events in batches of 50
            let events = eventStore.events
            if !events.isEmpty {
                statusMessage = "上传记录数据（\(events.count) 条）…"
                let batches = stride(from: 0, to: events.count, by: 50).map {
                    Array(events[$0..<min($0 + 50, events.count)])
                }
                for (i, batch) in batches.enumerated() {
                    for event in batch {
                        try await syncService.pushEvent(event)
                    }
                    progress = 0.1 + 0.7 * Double(i + 1) / Double(batches.count)
                }
            }

            // Step 3: push growth records
            let growth = growthStore.records
            if !growth.isEmpty, let baby {
                statusMessage = "上传成长记录（\(growth.count) 条）…"
                for record in growth {
                    try await syncService.pushGrowthRecord(record)
                }
            }

            progress = 1.0
            statusMessage = "迁移完成 ✓"
            UserDefaults.standard.set(true, forKey: Self.migratedKey)
        } catch {
            self.error = (error as? SyncError)?.errorDescription ?? error.localizedDescription
        }

        isRunning = false
    }
}
