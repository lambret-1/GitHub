import SwiftUI

// MARK: - 仓库统计视图
struct RepositoryStatsView: View {
    let owner: String
    let repo: String
    @EnvironmentObject var appState: AppState

    @State private var repository: Repository?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                loadingSection
            } else if let error = errorMessage {
                errorSection(error: error)
            } else if let repo = repository {
                // 概览统计
                overviewSection(repo: repo)

                // 详细统计
                detailsSection(repo: repo)

                // 仓库信息
                infoSection(repo: repo)
            }
        }
        .navigationTitle("仓库统计")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadRepository()
        }
        .refreshable {
            loadRepository()
        }
    }

    // MARK: - 加载中
    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - 错误
    private func errorSection(error: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))  // 字体大小40pt，控制文字显示尺寸
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    loadRepository()
                }
                .buttonStyle(.borderedProminent)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - 概览统计
    private func overviewSection(repo: Repository) -> some View {
        Section("概览") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statCard(
                    icon: "star.fill",
                    color: .yellow,
                    title: "星标",
                    value: "\(repo.stargazersCount ?? 0)"
                )

                statCard(
                    icon: "tuningfork",
                    color: .purple,
                    title: "Fork",
                    value: "\(repo.forksCount ?? 0)"
                )

                statCard(
                    icon: "eye.fill",
                    color: .blue,
                    title: "Watch",
                    value: "\(repo.watchersCount ?? 0)"
                )

                statCard(
                    icon: "exclamationmark.circle.fill",
                    color: .green,
                    title: "开放Issue",
                    value: "\(repo.openIssuesCount ?? 0)"
                )
            }
            .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - 统计卡片
    private func statCard(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))  // 字体大小24pt，控制文字显示尺寸
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))  // 字体大小22pt，控制文字显示尺寸
                .foregroundColor(appState.isDarkMode ? .white : .primary)

            Text(title)
                .font(.system(size: 12))  // 字体大小12pt，控制文字显示尺寸
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)  // 垂直内边距16pt，控制上下留白间距
        .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(12)  // 圆角半径12pt，控制视图边角圆润程度
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - 详细统计
    private func detailsSection(repo: Repository) -> some View {
        Section("详细信息") {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                    .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                Text("仓库大小")
                Spacer()
                Text(repo.formattedSize)
                    .foregroundColor(.secondary)
            }

            if let language = repo.language {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .foregroundColor(.orange)
                        .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                    Text("主要语言")
                    Spacer()
                    Text(language)
                        .foregroundColor(.secondary)
                }
            }

            if let license = repo.license {
                HStack {
                    Image(systemName: "scroll")
                        .foregroundColor(.green)
                        .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                    Text("开源协议")
                    Spacer()
                    Text(license.name)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Image(systemName: "lock")
                    .foregroundColor(repo.isPrivate ? .orange : .green)
                    .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                Text("可见性")
                Spacer()
                Text(repo.isPrivate ? "私有" : "公开")
                    .foregroundColor(.secondary)
            }

            if let defaultBranch = repo.defaultBranch {
                HStack {
                    Image(systemName: "branch")
                        .foregroundColor(.purple)
                        .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                    Text("默认分支")
                    Spacer()
                    Text(defaultBranch)
                        .foregroundColor(.secondary)
                }
            }

            if repo.是Fork {
                HStack {
                    Image(systemName: "tuningfork")
                        .foregroundColor(.purple)
                        .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                    Text("Fork来源")
                    Spacer()
                    if let parent = repo.parent {
                        Text("\(parent.ownerName)/\(parent.name)")
                            .foregroundColor(.blue)
                    } else {
                        Text("未知")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if repo.已归档 {
                HStack {
                    Image(systemName: "archivebox")
                        .foregroundColor(.gray)
                        .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                    Text("已归档")
                    Spacer()
                    Text("是")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 仓库信息
    private func infoSection(repo: Repository) -> some View {
        Section("时间信息") {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                Text("创建时间")
                Spacer()
                Text(repo.formattedCreateTime ?? "未知")
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                    .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                Text("更新时间")
                Spacer()
                Text(repo.formattedUpdateTime)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "link")
                    .foregroundColor(.gray)
                    .frame(width: 24)  // 视图宽度24pt，控制组件水平尺寸
                Text("仓库地址")
                Spacer()
                Text(repo.fullName)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    // MARK: - 加载仓库信息
    private func loadRepository() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getRepository(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let repoInfo):
                    repository = repoInfo
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
