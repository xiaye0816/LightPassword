import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            PasswordListView()
                .tabItem { Label("密码", systemImage: "key.fill") }
            TrashView()
                .tabItem { Label("回收站", systemImage: "trash") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
    }
}
