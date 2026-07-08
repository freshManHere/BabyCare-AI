import Foundation
import UIKit

// MARK: - Offline Sync Manager
// - Writes go local first, then are queued for remote push.
// - On foreground, drains outgoing queue AND pulls incremental updates from server.

@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()

    /// Injected by AppState after init so pullUpdates can read the current baby
    weak var appState: AppState?
    private init() {
        loadQueue()          // ← Restore persisted queue on launch
        observeForeground()
    }

    // MARK: - State
    /// The current user id, used to namespace all per-user storage keys.
    /// Set by AppState on sign-in; cleared on sign-out.
    var currentUserId: String = UserDefaults.standard.string(forKey: "sync_current_user_id") ?? "" {
        didSet { UserDefaults.standard.set(currentUserId, forKey: "sync_current_user_id") }
    }

    private func key(_ base: String) -> String {
        currentUserId.isEmpty ? base : "\(currentUserId)_\(base)"
    }

    var lastSyncDateEvents: Date? {
        get { UserDefaults.standard.object(forKey: key("last_sync_date_events")) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: key("last_sync_date_events")) }
    }
    var lastSyncDateGrowth: Date? {
        get { UserDefaults.standard.object(forKey: key("last_sync_date_growth")) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: key("last_sync_date_growth")) }
    }
    var lastSyncDate: Date? {
        get { lastSyncDateEvents }
        set { lastSyncDateEvents = newValue; lastSyncDateGrowth = newValue }
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
            UserDefaults.standard.set(try? JSONEncoder().encode(pendingQueue), forKey: key("sync_pending_queue_v1"))
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: key("sync_pending_queue_v1")),
              let items = try? JSONDecoder().decode([PendingItem].self, from: data)
        else { return }
        pendingQueue = items
    }

    /// Call after setting currentUserId to load the correct user's queue from storage.
    func loadQueueForCurrentUser() {
        loadQueue()
    }

    /// Call on sign-out: discard pending queue and reset sync timestamps for this user.
    /// ORDER MATTERS: clear timestamps before clearing currentUserId so key() still
    /// returns the user-namespaced key when nil is written to UserDefaults.
    func clearForSignOut() {
        pendingQueue = []
        lastSyncDateEvents = nil   // must come before currentUserId = ""
        lastSyncDateGrowth = nil   // must come before currentUserId = ""
        currentUserId = ""
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
        defer { isSyncing = false }   // Guaranteed reset even on unexpected exit

        let sync: any SyncService = RemoteSyncService()
        var remaining: [PendingItem] = []

        // Snapshot the current queue; new items added during drain are handled in the retry below
        let itemsToProcess = pendingQueue

        for item in itemsToProcess {
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
                remaining.append(item)
            }
        }

        // Keep items that failed + any newly enqueued during this drain
        let processedIds = Set(itemsToProcess.map(\.id))
        let newlyAdded = pendingQueue.filter { !processedIds.contains($0.id) }
        pendingQueue = remaining + newlyAdded
    }

    // MARK: - Incremental pull
    /// Pulls updates for ALL babies in the current account, not just currentBaby.
    /// Timestamps are only advanced when ALL babies succeed, so a partial failure
    /// does not cause data to be permanently skipped on the next sync.
    func pullUpdates() async {
        guard APIClient.shared.isAuthenticated else { return }
        let sync: any SyncService = RemoteSyncService()

        // Fetch the full baby list for this account
        let babies: [Baby]
        do {
            babies = try await sync.fetchBabies()
        } catch { return }  // can't sync without knowing the babies

        // Refresh the current baby profile (name, avatar, etc.) from server.
        // This ensures profile changes made on another device propagate here.
        if let appState, let local = appState.currentBaby,
           let matched = babies.first(where: { $0.id == local.id }) {
            appState.currentBaby = matched
        }

        let eventStore = EventStore.shared
        let growthStore = GrowthStore.shared
        var eventsAllSucceeded = true
        var growthAllSucceeded = true

        for baby in babies {
            // Pull events independently per baby
            do {
                let since = lastSyncDateEvents ?? Date(timeIntervalSince1970: 0)
                let updatedEvents = try await sync.syncEvents(babyId: baby.id, since: since)
                for event in updatedEvents {
                    if event.deletedAt != nil { eventStore.delete(event) }
                    else { eventStore.upsert(event) }
                }
            } catch {
                eventsAllSucceeded = false  // this baby failed; don't advance timestamp
            }

            // Pull growth records independently per baby
            do {
                let since = lastSyncDateGrowth ?? Date(timeIntervalSince1970: 0)
                let updatedGrowth = try await sync.syncGrowthRecords(babyId: baby.id, since: since)
                for record in updatedGrowth {
                    growthStore.upsert(record, syncOnly: true)
                }
            } catch {
                growthAllSucceeded = false
            }
        }

        // Only advance the timestamp if every baby succeeded,
        // so failed babies are retried on next sync rather than silently skipped.
        if eventsAllSucceeded { lastSyncDateEvents = Date() }
        if growthAllSucceeded { lastSyncDateGrowth = Date() }
    }

    // MARK: - Foreground trigger
    private func observeForeground() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.drainQueue()    // push pending local writes
                await self?.pullUpdates()   // pull remote changes
            }
        }
    }
}
