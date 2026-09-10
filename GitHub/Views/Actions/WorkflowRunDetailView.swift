import SwiftUI

// MARK: - 工作流运行详情视图

struct WorkflowRunDetailView: View {
    let owner: String
    let repo: String
    @State var run: WorkflowRun

    @State private var jobs: [WorkflowJob] = []
    @State private var isLoadingJobs: Bool = false
    @State private var errorMessage: String?
    @State private var showCancelAlert: Bool = false
    @State private var showRerunAlert: Bool = false
    @State private var isRefreshing: Bool = false

    var body: some View {
        List {
            // 运行状态概览
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // 状态图标和名称
                    HStack {
                        Image(systemName: run.statusIcon)
                            .font(.largeTitle)
                            .foregroundColor(Color(run.statusColor))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("运行 #\(run.runNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 状态标签
                    HStack {
                        Text(run.statusDisplay)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color(run.statusColor))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(run.statusColor).opacity(0.1))
                            .cornerRadius(8)

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            // 运行详情信息
            Section("运行详情") {
                detailRow(icon: "branch", title: "分支", value: run.headBranch)
                detailRow(icon: "chevron.left.forwardslash.chevron.right", title: "提交", value: run.shortSha)
                detailRow(icon: "bolt", title: "触发事件", value: run.eventDisplay)
                detailRow(icon: "clock", title: "创建时间", value: run.formattedCreatedAt)
                if let actor = run.actor {
                    detailRow(icon: "person", title: "触发者", value: actor.login)
                }
                if let message = run.headCommit?.message {
                    detailRow(icon: "text.alignleft", title: "提交信息", value: message)
                }
            }

            // 操作按钮
            if run.status == "in_progress" || run.status == "queued" {
                Section {
                    Button(action: {
                        showCancelAlert = true
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("取消运行")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            if run.status == "completed" {
                Section {
                    Button(action: {
                        showRerunAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("重新运行")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            // 作业列表
            Section("作业 (\(jobs.count))") {
                if isLoadingJobs && jobs.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("加载作业中...")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if let error = errorMessage, jobs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            loadJobs()
                        }
                        .font(.caption)
                    }
                    .padding(.vertical)
                    .listRowSeparator(.hidden)
                } else if jobs.isEmpty {
                    Text("暂无作业")
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(jobs) { job in
                        NavigationLink(destination: JobLogView(owner: owner, repo: repo, job: job)) {
                            JobRow(job: job)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("运行详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if jobs.isEmpty {
                loadJobs()
            }
        }
        .refreshable {
            isRefreshing = true
            loadJobs()
            refreshRun()
        }
        .alert("取消运行", isPresented: $showCancelAlert) {
            Button("取消运行", role: .destructive) {
                cancelRun()
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("确定要取消此运行吗？")
        }
        .alert("重新运行", isPresented: $showRerunAlert) {
            Button("重新运行") {
                rerunRun()
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("确定要重新运行此工作流吗？")
        }
    }

    // MARK: - 详情行视图

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 数据加载

    private func loadJobs() {
        isLoadingJobs = true
        errorMessage = nil

        GitHubAPI.shared.getWorkflowJobs(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                isLoadingJobs = false
                isRefreshing = false
                switch result {
                case .success(let jobs):
                    self.jobs = jobs
                case .failure(let error):
                    self.errorMessage = "加载作业失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshRun() {
        GitHubAPI.shared.getWorkflowRun(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedRun):
                    self.run = updatedRun
                case .failure:
                    break
                }
            }
        }
    }

    private func cancelRun() {
        GitHubAPI.shared.cancelWorkflowRun(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 刷新运行状态
                    refreshRun()
                    loadJobs()
                case .failure(let error):
                    errorMessage = "取消运行失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func rerunRun() {
        GitHubAPI.shared.rerunWorkflowRun(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 刷新运行状态
                    refreshRun()
                    loadJobs()
                case .failure(let error):
                    errorMessage = "重新运行失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 作业行视图

struct JobRow: View {
    let job: WorkflowJob

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: job.statusIcon)
                .font(.title3)
                .foregroundColor(Color(job.statusColor))

            VStack(alignment: .leading, spacing: 4) {
                // 作业名称
                Text(job.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // 运行时长和 Runner
                HStack(spacing: 8) {
                    if let duration = job.durationDisplay {
                        Text(duration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let runner = job.runnerName {
                        Text("· \(runner)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 状态文本
            Text(job.statusDisplay)
                .font(.caption2)
                .foregroundColor(Color(job.statusColor))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 作业日志视图

struct JobLogView: View {
    let owner: String
    let repo: String
    let job: WorkflowJob

    @State private var logs: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSteps: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // 作业信息头部
            HStack {
                Image(systemName: job.statusIcon)
                    .foregroundColor(Color(job.statusColor))
                Text(job.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(job.statusDisplay)
                    .font(.caption)
                    .foregroundColor(Color(job.statusColor))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            // 步骤列表（可折叠）
            if let steps = job.steps, !steps.isEmpty {
                DisclosureGroup(isExpanded: $showSteps) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(steps) { step in
                                VStack(spacing: 4) {
                                    Image(systemName: step.statusIcon)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(step.statusColor))
                                    Text(step.name)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                        .frame(width: 80)
                                    if let duration = step.durationDisplay {
                                        Text(duration)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                    }
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                        Text("步骤 (\(steps.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // 日志内容
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("加载日志中...")
                        Spacer()
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("重试") {
                            loadLogs()
                        }
                        .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding()
                } else if logs.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("暂无日志")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    // 日志文本视图
                    ScrollView {
                        Text(logs)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .background(Color(.systemBackground))
                }
            }
        }
        .navigationTitle("作业日志")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if logs.isEmpty {
                loadLogs()
            }
        }
    }

    // MARK: - 数据加载

    private func loadLogs() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getJobLogs(owner: owner, repo: repo, jobId: job.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let logs):
                    self.logs = logs
                case .failure(let error):
                    self.errorMessage = "加载日志失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
