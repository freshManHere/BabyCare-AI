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
    @Published var currentBaby: Baby? = Baby.preview
    /// Set by HomeView when tapping an overview card; consumed by RecordsView
    @Published var pendingRecordsFilter: EventLabel? = nil

    func switchToTab(_ tab: AppTab) {
        selectedTab = tab
    }

    func switchToRecords(filter: EventLabel) {
        pendingRecordsFilter = filter
        selectedTab = .records
    }
}
