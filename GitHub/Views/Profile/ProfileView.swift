import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if let user = appState.currentUser {
                    // 用户信息卡片
                    Section {
                        VStack(spacing: 16) {
                            // 头像
                            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                            
                            // 姓名和用户名
                            VStack(spacing: 4) {
                                Text(user.displayName)
                                    .font(.title2.bold())
                                Text("@\(user.login)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // 简介
                            if let bio = user.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // 统计数据
                            HStack(spacing: 30) {
                                StatView(number: user.publicRepos, label: "仓库")
                                StatView(number: user.followers, label: "粉丝")
                                StatView(number: user.following, label: "关注")
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    
                    // 详细信息
                    Section("个人信息") {
                        if let company = user.company, !company.isEmpty {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                Text("公司")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(company)
                            }
                        }
                        
                        if let location = user.location, !location.isEmpty {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                Text("位置")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(location)
                            }
                        }
                        
                        if let blog = user.blog, !blog.isEmpty {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                Text("博客")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(blog)
                                    .lineLimit(1)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                                .frame(width: 30)
                            Text("注册时间")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.formattedDate)
                        }
                    }
                    
                    // 账号设置
                    Section("账号") {
                        NavigationLink(destination: AccountManagerView()) {
                            HStack {
                                Image(systemName: "person.2.circle")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("账号管理")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(AccountManager.shared.accounts.count) 个账号")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        Button(action: {
                            if let url = URL(string: user.htmlUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("在 GitHub 查看主页")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        NavigationLink(destination: AboutView()) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("关于")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("v\(AppVersion.currentVersion)")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                    .frame(width: 30)
                                Text("退出登录")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("加载中...")
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("我的")
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("确认退出"),
                message: Text("退出后需要重新输入 Token 才能登录"),
                primaryButton: .destructive(Text("退出")) {
                    appState.logout()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
}

struct StatView: View {
    let number: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(number)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState.shared)
    }
}
