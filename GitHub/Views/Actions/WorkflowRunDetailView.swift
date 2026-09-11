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
    // 旋转动画状态
    @State private var rotationAngle: Double = 0
    // 失败日志跳转状态
    @State private var showFailedJobLog: Bool = false
    @State private var failedJob: WorkflowJob?

    var body: some View {
        List {
            // 运行状态概览
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // 状态图标和名称
                    HStack {
                        ZStack {
                            if run.status == "in_progress" {
                                // 进行中：旋转的循环箭头图标
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.largeTitle)
                                    .foregroundColor(Color(run.statusColor))
                                    .rotationEffect(.degrees(rotationAngle))
                                    .onAppear {
                                        // 启动无限旋转动画
                                        withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                            rotationAngle = 360
                                        }
                                    }
                            } else if run.status == "queued" || run.status == "pending" {
                                // 排队中：脉冲动画
                                Image(systemName: "clock")
                                    .font(.largeTitle)
                                    .foregroundColor(Color(run.statusColor))
                                    .opacity(0.5 + 0.5 * sin(rotationAngle / 180 * .pi))
                                    .onAppear {
                                        // 启动脉冲动画
                                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                            rotationAngle = 360
                                        }
                                    }
                            } else {
                                // 已完成：静态图标
                                Image(systemName: run.statusIcon)
                                    .font(.largeTitle)
                                    .foregroundColor(Color(run.statusColor))
                            }
                        }
                        .frame(width: 40)

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

                        // 失败时显示退出码或查看日志按钮（点击跳转到失败日志）
                        if run.conclusion == "failure", let failedJob = jobs.first(where: { $0.conclusion == "failure" }) {
                            Button(action: {
                                self.failedJob = failedJob
                                self.showFailedJobLog = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    if let exitCode = failedJob.exitCode {
                                        Text("退出码: \(exitCode)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    } else {
                                        Text("查看失败日志")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

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
            await refreshAllAsync()
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
        // 隐藏的NavigationLink，用于点击退出码跳转到失败日志
        .background(
            NavigationLink(destination: Group {
                if let job = failedJob {
                    JobLogView(owner: owner, repo: repo, job: job)
                }
            }, isActive: $showFailedJobLog) {
                EmptyView()
            }
            .hidden()
        )
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

    private func loadJobs(completion: (() -> Void)? = nil) {
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
                completion?()
            }
        }
    }

    private func refreshRun(completion: (() -> Void)? = nil) {
        GitHubAPI.shared.getWorkflowRun(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedRun):
                    self.run = updatedRun
                case .failure:
                    break
                }
                completion?()
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

    // MARK: - 异步刷新方法（用于下拉刷新）

    private func refreshAllAsync() async {
        await withCheckedContinuation { continuation in
            // 使用 DispatchGroup 等待两个请求都完成
            let group = DispatchGroup()

            group.enter()
            loadJobs {
                group.leave()
            }

            group.enter()
            refreshRun {
                group.leave()
            }

            // 所有请求完成后，最小延迟确保刷新动画流畅
            group.notify(queue: .main) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isRefreshing = false
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - 作业行视图

struct JobRow: View {
    let job: WorkflowJob
    // 旋转动画状态
    @State private var rotationAngle: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标（进行中时动态旋转）
            ZStack {
                if job.status == "in_progress" {
                    // 进行中：旋转的循环箭头图标
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                        .foregroundColor(Color(job.statusColor))
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            // 启动无限旋转动画
                            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                } else if job.status == "queued" || job.status == "pending" {
                    // 排队中：脉冲动画
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundColor(Color(job.statusColor))
                        .opacity(0.5 + 0.5 * sin(rotationAngle / 180 * .pi))
                        .onAppear {
                            // 启动脉冲动画
                            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                rotationAngle = 360
                            }
                        }
                } else {
                    // 已完成：静态图标
                    Image(systemName: job.statusIcon)
                        .font(.title3)
                        .foregroundColor(Color(job.statusColor))
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                // 作业名称
                Text(job.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // 运行时长和 Runner
                HStack(spacing: 8) {
                    Text(job.durationDisplay)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let runner = job.runnerName {
                        Text("· \(runner)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 状态文本和退出码
            HStack(spacing: 6) {
                Text(job.statusDisplay)
                    .font(.caption2)
                    .foregroundColor(Color(job.statusColor))

                // 失败时显示退出码
                if job.conclusion == "failure", let exitCode = job.exitCode {
                    Text("(\(exitCode))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
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
                HStack(spacing: 6) {
                    Text(job.statusDisplay)
                        .font(.caption)
                        .foregroundColor(Color(job.statusColor))
                    // 失败时显示退出码
                    if job.conclusion == "failure" {
                        if let exitCode = job.exitCode {
                            Text("退出码: \(exitCode)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        } else {
                            Text("退出码: 未知")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
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
                                    Text(step.durationDisplay)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
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
                    VStack(spacing: 0) {
                        // 退出码信息栏（失败时显示）
                        if job.conclusion == "failure" {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("作业执行失败")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                Spacer()
                                if let exitCode = job.exitCode {
                                    Text("退出码: \(exitCode)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                } else {
                                    Text("退出码: 未知（GitHub未返回）")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                        }

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
