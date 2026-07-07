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

    /// Auth state: nil = not decided yet, true = authenticated or skipped, false = needs login
    @Published var isAuthenticated: Bool

    private static let babyKey = "saved_baby_v1"
    private static let skippedAuthKey = "skipped_auth_v1"

    nonisolated(unsafe) private var signOutObserver: NSObjectProtocol?

    init() {
        currentBaby = Self.loadBaby()
        let hasToken = KeychainHelper.load(key: "access_token") != nil
        let skipped  = UserDefaults.standard.bool(forKey: Self.skippedAuthKey)
        isAuthenticated = hasToken || skipped

        // Give SyncManager a reference so pullUpdates() can read currentBaby
        SyncManager.shared.appState = self

        // Listen for sign-out events (401 from APIClient)
        signOutObserver = NotificationCenter.default.addObserver(
            forName: .userDidSignOut, object: nil, queue: .main
        ) { [weak self] _ in
            self?.isAuthenticated = false
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
        // Always reconcile the local selected baby with the server account.
        // If this device has no local baby, or has a baby from another account,
        // switch to one of the babies returned by the server before pulling data.
        Task {
            await syncCurrentBabyFromServer()
            await SyncManager.shared.pullUpdates()
        }
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
                currentBaby = matched
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
        APIClient.shared.logout()
        UserDefaults.standard.removeObject(forKey: Self.skippedAuthKey)
        isAuthenticated = false
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
        guard let data = UserDefaults.standard.data(forKey: babyKey),
              let baby = try? JSONDecoder().decode(Baby.self, from: data) else {
            return nil
        }
        return baby
    }
}
