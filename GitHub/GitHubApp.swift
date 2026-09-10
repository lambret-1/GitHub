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
    // 使用@State绑定当前选中的tab，防止TabView状态混乱导致底部菜单栏消失
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RepoListView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("仓库")
                }
                .tag(0)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("我的")
                }
                .tag(1)
        }
        // 根据暗黑模式自动切换强调色，浅色模式用黑色，暗黑模式用白色
        .accentColor(appState.isDarkMode ? .white : .black)
        // 使用id()强制TabView在登录状态或暗黑模式变化时重新渲染，防止底部菜单栏消失
        .id("MainTabView-\(appState.isLoggedIn)-\(appState.isDarkMode)")
        // 监听tab切换，强制恢复TabBar显示，防止编辑模式下返回导致TabBar一直隐藏
        .onChange(of: selectedTab) { _ in
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    var responder: UIResponder? = window.rootViewController
                    while let next = responder {
                        if let tabBarController = next as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                            break
                        }
                        responder = next.next
                    }
                }
            }
        }
        // 强制设置TabView的背景色，防止在某些情况下背景透明导致菜单栏"消失"
        .onAppear {
            // iOS 15+ 需要设置UITabBar的外观
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            // 页面出现时强制恢复TabBar显示
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    var responder: UIResponder? = window.rootViewController
                    while let next = responder {
                        if let tabBarController = next as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                            break
                        }
                        responder = next.next
                    }
                }
            }
        }
    }
}
