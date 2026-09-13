import SwiftUI

// MARK: - 自助托管Runner管理视图

struct RunnerManagementView: View {
    let owner: String
    let repo: String

    @State private var runners: [SelfHostedRunner] = []
    @State private var totalCount: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMore: Bool = true
    @State private var deletingRunnerId: Int?
    @State private var showDeleteAlert: Bool = false
    @State private var runnerToDelete: SelfHostedRunner?

    var body: some View {
        Group {
            if isLoading && runners.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("加载Runner列表中...")
                    Spacer()
                }
            } else if let error = errorMessage, runners.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadRunners()
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }
                .padding()
            } else if runners.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "cpu")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无自助托管Runner")
                        .foregroundColor(.secondary)
                    Text("可以在仓库设置中添加自助托管Runner")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List {
                    // 统计概览
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Runner总数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalCount) 个")
                                    .font(.headline)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("在线/忙碌/离线")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(onlineCount)/\(busyCount)/\(offlineCount)")
                                    .font(.headline)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Runner列表
                    Section("Runner列表") {
                        ForEach(runners) { runner in
                            runnerRow(runner: runner)
                                .onAppear {
                                    if runner.id == runners.last?.id && hasMore && !isLoading {
                                        loadMoreRunners()
                                    }
                                }
                        }

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    currentPage = 1
                    hasMore = true
                    await loadRunnersAsync()
                }
            }
        }
        .navigationTitle("Runner管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("删除Runner", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                if let runner = runnerToDelete {
                    deleteRunner(runner)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let runner = runnerToDelete {
                Text("确定要删除Runner「\(runner.name)」吗？删除后该Runner将无法再接收构建任务。")
            } else {
                Text("确定要删除此Runner吗？")
            }
        }
        .onAppear {
            if runners.isEmpty {
                loadRunners()
            }
        }
    }

    // MARK: - Runner行视图

    private func runnerRow(runner: SelfHostedRunner) -> some View {
        HStack(spacing: 12) {
            Image(systemName: runner.osIcon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(runner.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Image(systemName: runner.statusIcon)
                        .font(.system(size: 10))
                        .foregroundColor(runner.statusColor)
                }

                HStack(spacing: 6) {
                    Text(runner.os)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(runner.statusDisplay)
                        .font(.caption2)
                        .foregroundColor(runner.statusColor)
                }

                Text("标签: \(runner.labelsDisplay)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // 删除按钮
            if deletingRunnerId == runner.id {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    runnerToDelete = runner
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 计算属性

    private var onlineCount: Int {
        return runners.filter { $0.status == "online" && !$0.busy }.count
    }

    private var busyCount: Int {
        return runners.filter { $0.status == "online" && $0.busy }.count
    }

    private var offlineCount: Int {
        return runners.filter { $0.status == "offline" }.count
    }

    // MARK: - 数据加载

    private func loadRunners() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getRunners(owner: owner, repo: repo, page: 1) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    self.runners = data.runners
                    self.totalCount = data.totalCount
                    self.hasMore = data.runners.count >= 30
                case .failure(let error):
                    self.errorMessage = "加载Runner列表失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadMoreRunners() {
        currentPage += 1

        GitHubAPI.shared.getRunners(owner: owner, repo: repo, page: currentPage) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.runners.append(contentsOf: data.runners)
                    self.hasMore = data.runners.count >= 30
                case .failure:
                    self.hasMore = false
                }
            }
        }
    }

    private func loadRunnersAsync() async {
        await withCheckedContinuation { continuation in
            loadRunners()
            continuation.resume()
        }
    }

    // MARK: - 删除Runner

    private func deleteRunner(_ runner: SelfHostedRunner) {
        deletingRunnerId = runner.id

        GitHubAPI.shared.deleteRunner(owner: owner, repo: repo, runnerId: runner.id) { result in
            DispatchQueue.main.async {
                deletingRunnerId = nil
                switch result {
                case .success:
                    runners.removeAll { $0.id == runner.id }
                    totalCount -= 1
                case .failure(let error):
                    errorMessage = "删除Runner失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
