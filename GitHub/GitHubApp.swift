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
        }
    }
}

struct MainTabView: View {
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
        .accentColor(.black)
    }
}
