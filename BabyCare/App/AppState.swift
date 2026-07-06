import SwiftUI

// MARK: - App Tab
enum AppTab: Hashable {
    case home
    case records
    case assistant
    case mine
}

// MARK: - App State
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

    private static let babyKey = "saved_baby_v1"

    init() {
        currentBaby = Self.loadBaby()
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
