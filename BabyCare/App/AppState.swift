import SwiftUI

// MARK: - App Tab
enum AppTab: Hashable {
    case home
    case records
    case assistant
    case mine
}
@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var currentBaby: Baby? {
        didSet { saveBaby() }
    }
    /// Set by HomeView when tapping an overview card; consumed by RecordsView
    @Published var pendingRecordsFilter: EventLabel? = nil

    /// Persists chat history across tab switches
    let assistantViewModel = AssistantViewModel()

    /// Auth state
    @Published var isAuthenticated: Bool
    /// True while the initial baby + events sync is running after sign-in
    @Published var isSyncingAfterLogin = false
    /// True if the initial sync failed (network error, server down, etc.)
    @Published var syncAfterLoginFailed = false

    private static let babyKey = "saved_baby_v1"
    private static let skippedAuthKey = "skipped_auth_v1"
    /// Timestamp of the last time the user explicitly saved a baby profile on
    /// this device.  Keyed by baby UUID so multiple babies are handled safely.
    /// Cleared when the server push is confirmed so pullUpdates() knows whether
    /// local or server is the authoritative source for the avatar.
    func localBabySavedAt(for babyId: UUID) -> Date? {
        UserDefaults.standard.object(forKey: "local_baby_saved_\(babyId)") as? Date
    }
    func setLocalBabySavedAt(_ date: Date?, for babyId: UUID) {
        if let date {
            UserDefaults.standard.set(date, forKey: "local_baby_saved_\(babyId)")
        } else {
            UserDefaults.standard.removeObject(forKey: "local_baby_saved_\(babyId)")
        }
    }

    nonisolated(unsafe) private var signOutObserver: NSObjectProtocol?

    init() {
        currentBaby = Self.loadBaby()
        let hasToken = KeychainHelper.load(key: "access_token") != nil
        let skipped  = UserDefaults.standard.bool(forKey: Self.skippedAuthKey)
        isAuthenticated = hasToken || skipped

        // Give SyncManager a reference so pullUpdates() can read currentBaby
        SyncManager.shared.appState = self

        // On cold start with an existing token, restore the userId so SyncManager
        // uses the correct per-user UserDefaults keys (queue, sync timestamps).
        if hasToken, let userId = decodeUserIdFromToken() {
            SyncManager.shared.currentUserId = userId
            SyncManager.shared.loadQueueForCurrentUser()
        }

        // Listen for sign-out events (401 from APIClient)
        signOutObserver = NotificationCenter.default.addObserver(
            forName: .userDidSignOut, object: nil, queue: .main
        ) { [weak self] _ in
            self?.clearLocalState()
            self?.isAuthenticated = false
        }

        // If we have a token but no local baby data (e.g. after reinstall from Xcode
        // or device restore where Keychain persists but local files are gone),
        // run the same sync flow as didSignIn() so data is recovered automatically.
        if hasToken && currentBaby == nil && !skipped {
            isSyncingAfterLogin = true
            Task { await performInitialSync() }
        }
    }

    deinit {
        if let obs = signOutObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func didSignIn() {
        UserDefaults.standard.removeObject(forKey: Self.skippedAuthKey)
        isAuthenticated = true
        isSyncingAfterLogin = true
        syncAfterLoginFailed = false
        if let userId = decodeUserIdFromToken() {
            SyncManager.shared.currentUserId = userId
            SyncManager.shared.loadQueueForCurrentUser()
        }
        Task { await performInitialSync() }
    }

    /// Fetches baby profile + all events from server.
    /// Sets syncAfterLoginFailed if baby fetch fails so UI can show a retry button.
    func performInitialSync() async {
        await syncCurrentBabyFromServer()
        if currentBaby != nil {
            await SyncManager.shared.pullUpdates()
            syncAfterLoginFailed = false
        } else {
            // No baby fetched — could be network error or truly empty account
            syncAfterLoginFailed = true
        }
        isSyncingAfterLogin = false
    }

    func retryInitialSync() {
        syncAfterLoginFailed = false
        isSyncingAfterLogin = true
        Task { await performInitialSync() }
    }

    /// Extracts the userId claim from the JWT access token (no signature verification needed here).
    private func decodeUserIdFromToken() -> String? {
        guard let token = APIClient.shared.accessToken else { return nil }
        let parts = token.split(separator: ".");
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1])
        // Base64url → Base64
        let rem = payload.count % 4
        if rem > 0 { payload += String(repeating: "=", count: 4 - rem) }
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = json["userId"] as? String else { return nil }
        return userId
    }

    /// Reconciles local currentBaby with the authenticated account's babies.
    ///
    /// Cases handled:
    /// - New device: currentBaby is nil -> choose the first server baby.
    /// - Switched account: local currentBaby belongs to another account -> replace it.
    /// - Same account: keep the currently selected baby if it exists on the server.
    func syncCurrentBabyFromServer() async {
        do {
            let babies: [Baby] = try await APIClient.shared.request("/babies")
            guard !babies.isEmpty else {
                currentBaby = nil
                return
            }

            if let local = currentBaby,
               let matched = babies.first(where: { $0.id == local.id }) {
                // If the user has an unconfirmed local save, preserve their avatar
                // rather than overwriting it with the server's (potentially older) data.
                var merged = matched
                if localBabySavedAt(for: local.id) != nil, local.avatarData != nil {
                    merged.avatarData = local.avatarData
                }
                currentBaby = merged
            } else {
                currentBaby = babies.first
            }
        } catch {
            print("[AppState] syncCurrentBabyFromServer failed: \(error)")
        }
    }

    func skipAuth() {
        UserDefaults.standard.set(true, forKey: Self.skippedAuthKey)
        isAuthenticated = true
    }

    func signOut() {
        clearLocalState()
        APIClient.shared.logout()
        UserDefaults.standard.removeObject(forKey: Self.skippedAuthKey)
        isAuthenticated = false
    }

    /// Clears in-memory state for the current user.
    /// Only clears memory — disk files are intentionally preserved so data can be
    /// recovered if a 401 is spurious (e.g. transient server error).
    private func clearLocalState() {
        if let id = currentBaby?.id { setLocalBabySavedAt(nil, for: id) }
        currentBaby = nil
        EventStore.shared.events = []
        GrowthStore.shared.clearMemory()
        SyncManager.shared.clearForSignOut()
    }

    func switchToTab(_ tab: AppTab) {
        selectedTab = tab
    }

    func switchToRecords(filter: EventLabel) {
        pendingRecordsFilter = filter
        selectedTab = .records
    }

    private func saveBaby() {
        guard let baby = currentBaby,
              let data = try? JSONEncoder().encode(baby) else {
            UserDefaults.standard.removeObject(forKey: Self.babyKey)
            return
        }
        UserDefaults.standard.set(data, forKey: Self.babyKey)
    }

    private static func loadBaby() -> Baby? {
        guard let data = UserDefaults.standard.data(forKey: babyKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let dayOnly = DateFormatter()
            dayOnly.dateFormat = "yyyy-MM-dd"
            if let date = dayOnly.date(from: str) { return date }
            let full = ISO8601DateFormatter()
            full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = full.date(from: str) { return date }
            let noFrac = ISO8601DateFormatter()
            noFrac.formatOptions = [.withInternetDateTime]
            if let date = noFrac.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(str)"
            )
        }
        return try? decoder.decode(Baby.self, from: data)
    }
}
