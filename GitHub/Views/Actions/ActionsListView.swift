import SwiftUI

// MARK: - Actions 主视图

struct ActionsListView: View {
    let owner: String
    let repo: String

    @State private var selectedTab: Int = 0
    @State private var workflows: [Workflow] = []
    @State private var runs: [WorkflowRun] = []
    @State private var isLoadingWorkflows: Bool = false
    @State private var isLoadingRuns: Bool = false
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMoreRuns: Bool = true
    @State private var showTriggerAlert: Bool = false
    @State private var selectedWorkflow: Workflow?

    var body: some View {
        VStack(spacing: 0) {
            // 标签切换
            Picker("选择", selection: $selectedTab) {
                Text("运行记录").tag(0)
                Text("工作流").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                runsListView
            } else {
                workflowsListView
            }
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if workflows.isEmpty {
                loadWorkflows()
            }
            if runs.isEmpty {
                loadRuns()
            }
        }
        .alert(isPresented: $showTriggerAlert) {
            Alert(
                title: Text("触发工作流"),
                message: Text("确定要触发「\(selectedWorkflow?.name ?? "")」工作流吗？"),
                primaryButton: .default(Text("触发")) {
                    if let workflow = selectedWorkflow {
                        triggerWorkflow(workflow)
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - 运行记录列表

    private var runsListView: some View {
        Group {
            if isLoadingRuns && runs.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, runs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadRuns()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if runs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无运行记录")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(runs) { run in
                        NavigationLink(destination: WorkflowRunDetailView(owner: owner, repo: repo, run: run)) {
                            WorkflowRunRow(run: run)
                        }
                        .onAppear {
                            if run.id == runs.last?.id && hasMoreRuns && !isLoadingRuns {
                                loadMoreRuns()
                            }
                        }
                    }

                    if isLoadingRuns {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    currentPage = 1
                    hasMoreRuns = true
                    loadRuns()
                }
            }
        }
    }

    // MARK: - 工作流列表

    private var workflowsListView: some View {
        Group {
            if isLoadingWorkflows && workflows.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, workflows.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadWorkflows()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workflows.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bolt")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无工作流")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(workflows) { workflow in
                        WorkflowRow(workflow: workflow) {
                            selectedWorkflow = workflow
                            showTriggerAlert = true
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    loadWorkflows()
                }
            }
        }
    }

    // MARK: - 数据加载

    private func loadWorkflows() {
        isLoadingWorkflows = true
        errorMessage = nil

        GitHubAPI.shared.getWorkflows(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoadingWorkflows = false
                switch result {
                case .success(let workflows):
                    self.workflows = workflows
                case .failure(let error):
                    self.errorMessage = "加载工作流失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadRuns() {
        isLoadingRuns = true
        errorMessage = nil

        GitHubAPI.shared.getWorkflowRuns(owner: owner, repo: repo, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoadingRuns = false
                switch result {
                case .success(let runs):
                    self.runs = runs
                    self.hasMoreRuns = runs.count >= 30
                case .failure(let error):
                    self.errorMessage = "加载运行记录失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadMoreRuns() {
        currentPage += 1
        isLoadingRuns = true

        GitHubAPI.shared.getWorkflowRuns(owner: owner, repo: repo, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoadingRuns = false
                switch result {
                case .success(let newRuns):
                    self.runs.append(contentsOf: newRuns)
                    self.hasMoreRuns = newRuns.count >= 30
                case .failure:
                    self.currentPage -= 1
                }
            }
        }
    }

    private func triggerWorkflow(_ workflow: Workflow) {
        GitHubAPI.shared.triggerWorkflowDispatch(owner: owner, repo: repo, workflowId: workflow.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 触发成功后刷新运行记录
                    selectedTab = 0
                    currentPage = 1
                    hasMoreRuns = true
                    loadRuns()
                case .failure(let error):
                    errorMessage = "触发工作流失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 工作流运行行视图

struct WorkflowRunRow: View {
    let run: WorkflowRun

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: run.statusIcon)
                .font(.title2)
                .foregroundColor(Color(run.statusColor))

            VStack(alignment: .leading, spacing: 4) {
                // 工作流名称和运行编号
                HStack {
                    Text(run.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("#\(run.runNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 分支和提交信息
                HStack(spacing: 8) {
                    Image(systemName: "branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(run.headBranch)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(run.shortSha)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                // 触发事件和时间
                HStack(spacing: 8) {
                    Text(run.eventDisplay)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                    Text(run.formattedCreatedAt)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 状态文本
            Text(run.statusDisplay)
                .font(.caption)
                .foregroundColor(Color(run.statusColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(run.statusColor).opacity(0.1))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 工作流行视图

struct WorkflowRow: View {
    let workflow: Workflow
    var onTrigger: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 工作流图标
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                // 工作流名称
                Text(workflow.name)
                    .font(.headline)
                    .lineLimit(1)

                // 文件名
                Text(workflow.fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 状态
                HStack(spacing: 4) {
                    Circle()
                        .fill(workflow.state == "active" ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(workflow.stateDisplay)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 触发按钮
            Button(action: onTrigger) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 颜色扩展

extension Color {
    init(_ name: String) {
        switch name {
        case "systemGreen": self = .green
        case "systemRed": self = .red
        case "systemBlue": self = .blue
        case "systemOrange": self = .orange
        case "systemGray": self = .gray
        default: self = .gray
        }
    }
}
