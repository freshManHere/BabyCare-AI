import Foundation
import UIKit

// MARK: - Offline Sync Manager
// - Writes go local first, then are queued for remote push.
// - On foreground / network restore, drains the queue.
// - Incremental pull: fetches events updated since last sync time.

@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()
    private init() {
        loadQueue()          // ← Restore persisted queue on launch
        observeForeground()
    }

    // MARK: - State
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "last_sync_date") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "last_sync_date") }
    }
    var isSyncing = false
    var pendingCount: Int { pendingQueue.count }

    // MARK: - Queue (persisted as JSON)
    private struct PendingItem: Codable {
        enum Operation: String, Codable { case pushEvent, deleteEvent, pushGrowth, deleteGrowth }
        let id: UUID
        let operation: Operation
        let payload: Data
        let babyId: UUID
    }

    private var pendingQueue: [PendingItem] = [] {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(pendingQueue), forKey: "sync_pending_queue_v1")
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: "sync_pending_queue_v1"),
              let items = try? JSONDecoder().decode([PendingItem].self, from: data)
        else { return }
        pendingQueue = items
    }

    // Push a new or updated event
    func enqueueEvent(_ event: BabyEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        pendingQueue.append(PendingItem(id: UUID(), operation: .pushEvent, payload: data, babyId: event.babyId))
        Task { await drainQueue() }
    }

    func enqueueDeleteEvent(babyId: UUID, eventId: UUID) {
        let data = (try? JSONEncoder().encode(eventId)) ?? Data()
        pendingQueue.append(PendingItem(id: UUID(), operation: .deleteEvent, payload: data, babyId: babyId))
        Task { await drainQueue() }
    }

    func enqueueGrowthRecord(_ record: GrowthRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        pendingQueue.append(PendingItem(id: UUID(), operation: .pushGrowth, payload: data, babyId: record.babyId))
        Task { await drainQueue() }
    }

    func enqueueDeleteGrowthRecord(babyId: UUID, recordId: UUID) {
        let data = (try? JSONEncoder().encode(recordId)) ?? Data()
        pendingQueue.append(PendingItem(id: UUID(), operation: .deleteGrowth, payload: data, babyId: babyId))
        Task { await drainQueue() }
    }

    // MARK: - Drain (push pending items to backend)
    func drainQueue() async {
        guard !isSyncing, !pendingQueue.isEmpty, APIClient.shared.isAuthenticated else { return }
        isSyncing = true
        let sync: any SyncService = RemoteSyncService()
        var remaining: [PendingItem] = []

        for item in pendingQueue {
            do {
                switch item.operation {
                case .pushEvent:
                    if let event = try? JSONDecoder().decode(BabyEvent.self, from: item.payload) {
                        try await sync.pushEvent(event)
                    }
                case .deleteEvent:
                    if let id = try? JSONDecoder().decode(UUID.self, from: item.payload) {
                        try await sync.deleteEvent(babyId: item.babyId, id: id)
                    }
                case .pushGrowth:
                    if let record = try? JSONDecoder().decode(GrowthRecord.self, from: item.payload) {
                        try await sync.pushGrowthRecord(record)
                    }
                case .deleteGrowth:
                    if let id = try? JSONDecoder().decode(UUID.self, from: item.payload) {
                        try await sync.deleteGrowthRecord(babyId: item.babyId, id: id)
                    }
                }
            } catch {
                // Keep failed items in queue for retry
                remaining.append(item)
            }
        }
        pendingQueue = remaining
        isSyncing = false
    }

    // MARK: - Incremental pull
    func pullUpdates(babyId: UUID) async {
        guard APIClient.shared.isAuthenticated else { return }
        let since = lastSyncDate ?? Date(timeIntervalSince1970: 0)
        let sync: any SyncService = RemoteSyncService()
        do {
            let updatedEvents = try await sync.syncEvents(babyId: babyId, since: since)
            let store = EventStore.shared
            for event in updatedEvents {
                if event.deletedAt != nil {
                    store.delete(event)
                } else {
                    store.upsert(event)
                }
            }
            lastSyncDate = Date()   // Only update after successful sync
        } catch { /* silent fail — will retry next foreground event */ }
    }

    // MARK: - Foreground trigger
    private func observeForeground() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.drainQueue()
            }
        }
    }
}
