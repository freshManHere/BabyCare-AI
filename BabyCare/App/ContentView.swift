import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            RecordsView()
                .tabItem {
                    Label("记录", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(AppTab.records)

            AssistantView()
                .tabItem {
                    Label("助手", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(AppTab.assistant)

            MineView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(AppTab.mine)
        }
        .tint(.pink)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
