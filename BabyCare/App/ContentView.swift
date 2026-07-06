import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        if !appState.isAuthenticated {
            AuthView()
        } else if hSizeClass == .regular {
            // iPad / landscape: sidebar navigation
            iPadLayout
        } else {
            // iPhone / compact: tab bar
            iPhoneLayout
        }
    }

    // MARK: - iPhone / compact
    private var iPhoneLayout: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(AppTab.home)
            RecordsView()
                .tabItem { Label("记录", systemImage: "list.bullet.clipboard.fill") }
                .tag(AppTab.records)
            AssistantView()
                .tabItem { Label("助手", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.assistant)
            MineView()
                .tabItem { Label("我的", systemImage: "person.fill") }
                .tag(AppTab.mine)
        }
        .tint(.pink)
    }

    // MARK: - iPad / regular
    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                sidebarRow(tab: .home,      title: "首页", icon: "house.fill")
                sidebarRow(tab: .records,   title: "记录", icon: "list.bullet.clipboard.fill")
                sidebarRow(tab: .assistant, title: "助手", icon: "bubble.left.and.bubble.right.fill")
                sidebarRow(tab: .mine,      title: "我的", icon: "person.fill")
            }
            .navigationTitle("BabyCare")
            .listStyle(.sidebar)
        } detail: {
            switch appState.selectedTab {
            case .home:      HomeView()
            case .records:   RecordsView()
            case .assistant: AssistantView()
            case .mine:      MineView()
            }
        }
        .tint(.pink)
    }

    private func sidebarRow(tab: AppTab, title: String, icon: String) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(appState.selectedTab == tab ? Color.pink : Color.primary)
        }
        .listRowBackground(appState.selectedTab == tab ? Color.pink.opacity(0.12) : Color.clear)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
