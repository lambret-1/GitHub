import SwiftUI

// MARK: - Actions 主入口视图（重做版）

struct ActionsListView: View {
    let owner: String
    let repo: String

    // 标签页状态
    @State private var selectedTab: Int = 0

    // 运行记录相关状态
    @State private var runs: [WorkflowRun] = []
    @State private var isLoadingRuns: Bool = false
    @State private var runsError: String?
    @State private var currentPage: Int = 1
    @State private var hasMoreRuns: Bool = true

    // 工作流相关状态
    @State private var workflows: [Workflow] = []
    @State private var isLoadingWorkflows: Bool = false
    @State private var workflowsError: String?

    // 统计概览相关状态
    @State private var stats: RunStats?
    @State private var isLoadingStats: Bool = false

    // 筛选相关状态
    @State private var showFilter: Bool = false
    @State private var filterStatus: String = "all" // all/in_progress/success/failure
    @State private var filterBranch: String = ""

    // 触发工作流相关状态
    @State private var showTriggerAlert: Bool = false
    @State private var selectedWorkflow: Workflow?

    var body: some View {
        VStack(spacing: 0) {
            // 统计概览卡片
            statsOverviewCard

            // 标签切换
            Picker("选择", selection: $selectedTab) {
                Text("运行记录").tag(0)
                Text("工作流").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)

            // 内容区域
            if selectedTab == 0 {
                runsListView
            } else {
                workflowsListView
            }
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if runs.isEmpty {
                loadRuns()
            }
            if workflows.isEmpty {
                loadWorkflows()
            }
            if stats == nil {
                loadStats()
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

    // MARK: - 统计概览卡片

    private var statsOverviewCard: some View {
        HStack(spacing: 12) {
            // 总运行次数
            statItem(
                icon: "bolt.fill",
                color: .blue,
                value: "\(stats?.totalRuns ?? 0)",
                label: "总运行"
            )

            Divider()
                .frame(height: 40)

            // 成功率
            statItem(
                icon: "checkmark.circle.fill",
                color: .green,
                value: String(format: "%.0f%%", stats?.successRate ?? 0),
                label: "成功率"
            )

            Divider()
                .frame(height: 40)

            // 平均耗时
            statItem(
                icon: "clock.fill",
                color: .orange,
                value: stats?.averageDurationDisplay ?? "-",
                label: "平均耗时"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    private func statItem(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 运行记录列表

    private var runsListView: some View {
        Group {
            if isLoadingRuns && runs.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = runsError, runs.isEmpty {
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
                    await loadRunsAsync()
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
            } else if let error = workflowsError, workflows.isEmpty {
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
                        WorkflowCard(workflow: workflow) {
                            selectedWorkflow = workflow
                            showTriggerAlert = true
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await loadWorkflowsAsync()
                }
            }
        }
    }

    // MARK: - 数据加载

    private func loadRuns(completion: (() -> Void)? = nil) {
        isLoadingRuns = true
        runsError = nil

        GitHubAPI.shared.getWorkflowRuns(owner: owner, repo: repo, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoadingRuns = false
                switch result {
                case .success(let runs):
                    if currentPage == 1 {
                        self.runs = runs
                    } else {
                        self.runs.append(contentsOf: runs)
                    }
                    self.hasMoreRuns = runs.count >= 30
                case .failure(let error):
                    self.runsError = "加载运行记录失败: \(error.localizedDescription)"
                }
                completion?()
            }
        }
    }

    private func loadMoreRuns() {
        currentPage += 1
        loadRuns()
    }

    private func loadWorkflows(completion: (() -> Void)? = nil) {
        isLoadingWorkflows = true
        workflowsError = nil

        GitHubAPI.shared.getWorkflows(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoadingWorkflows = false
                switch result {
                case .success(let workflows):
                    self.workflows = workflows
                case .failure(let error):
                    self.workflowsError = "加载工作流失败: \(error.localizedDescription)"
                }
                completion?()
            }
        }
    }

    private func loadStats() {
        isLoadingStats = true
        // 加载最近30次运行用于统计
        GitHubAPI.shared.getWorkflowRuns(owner: owner, repo: repo, page: 1, perPage: 30) { result in
            DispatchQueue.main.async {
                self.isLoadingStats = false
                switch result {
                case .success(let runs):
                    var successCount = 0
                    var failureCount = 0
                    var cancelledCount = 0
                    var inProgressCount = 0
                    var totalDuration = 0
                    var durationCount = 0

                    for run in runs {
                        if run.status == "completed" {
                            switch run.conclusion {
                            case "success": successCount += 1
                            case "failure": failureCount += 1
                            case "cancelled": cancelledCount += 1
                            default: break
                            }
                        } else if run.status == "in_progress" {
                            inProgressCount += 1
                        }
                    }

                    self.stats = RunStats(
                        totalRuns: runs.count,
                        successCount: successCount,
                        failureCount: failureCount,
                        cancelledCount: cancelledCount,
                        inProgressCount: inProgressCount,
                        averageDurationSeconds: durationCount > 0 ? totalDuration / durationCount : nil
                    )
                case .failure:
                    self.stats = nil
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
                    runsError = "触发工作流失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 异步加载方法（用于下拉刷新）

    private func loadRunsAsync() async {
        await withCheckedContinuation { continuation in
            loadRuns {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    continuation.resume()
                }
            }
        }
    }

    private func loadWorkflowsAsync() async {
        await withCheckedContinuation { continuation in
            loadWorkflows {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - 工作流运行行视图（重做版）

struct WorkflowRunRow: View {
    let run: WorkflowRun
    @State private var rotationAngle: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            ZStack {
                if run.status == "in_progress" {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(Color(run.statusColor))
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                } else if run.status == "queued" || run.status == "pending" {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(Color(run.statusColor))
                        .opacity(0.5 + 0.5 * sin(rotationAngle / 180 * .pi))
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                rotationAngle = 360
                            }
                        }
                } else {
                    Image(systemName: run.statusIcon)
                        .font(.title2)
                        .foregroundColor(Color(run.statusColor))
                }
            }
            .frame(width: 30)

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

// MARK: - 工作流卡片视图（重做版）

struct WorkflowCard: View {
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
