import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        if !appState.isAuthenticated {
            AuthView()
        } else if appState.isSyncingAfterLogin {
            // Show loading while baby profile and events are being fetched
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("正在同步数据…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        } else if appState.syncAfterLoginFailed {
            // Sync failed (server unreachable, no network, etc.)
            VStack(spacing: 20) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary)
                Text("数据同步失败")
                    .font(.title3.bold())
                Text("请确认服务器正常运行后重试")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    appState.retryInitialSync()
                } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                        .frame(minWidth: 120)
                        .padding(.vertical, 10)
                        .background(Color.pink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button("暂不同步，离线使用") {
                    appState.syncAfterLoginFailed = false
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
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
