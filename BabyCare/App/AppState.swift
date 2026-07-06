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
