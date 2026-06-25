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

    func switchToTab(_ tab: AppTab) {
        selectedTab = tab
    }
}
