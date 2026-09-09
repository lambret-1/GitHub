import SwiftUI

@main
struct GitHubApp: App {
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoggedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            // 根据暗黑模式状态设置应用配色方案
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            RepoListView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("仓库")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("我的")
                }
        }
        // 根据暗黑模式自动切换强调色，浅色模式用黑色，暗黑模式用白色
        .accentColor(appState.isDarkMode ? .white : .black)
    }
}
