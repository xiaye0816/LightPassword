import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            PasswordListView()
                .tabItem { Label("密码", systemImage: "key.fill") }
                .tag(AppTab.passwords)
            TrashView()
                .tabItem { Label("回收站", systemImage: "trash") }
                .tag(AppTab.trash)
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}
