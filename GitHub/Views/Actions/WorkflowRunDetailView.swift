import SwiftUI

// MARK: - 工作流运行详情视图（重做版）

struct WorkflowRunDetailView: View {
    let owner: String
    let repo: String
    @State var run: WorkflowRun

    // 作业相关状态
    @State private var jobs: [WorkflowJob] = []
    @State private var isLoadingJobs: Bool = false
    @State private var jobsError: String?

    // 变更文件相关状态
    @State private var changedFiles: [ChangedFile] = []
    @State private var isLoadingFiles: Bool = false
    @State private var filesError: String?

    // Artifacts相关状态
    @State private var artifacts: [Artifact] = []
    @State private var isLoadingArtifacts: Bool = false
    @State private var artifactsError: String?
    @State private var downloadingArtifactId: Int?
    @State private var deletingArtifactId: Int?
    @State private var artifactToDelete: Artifact?
    @State private var showDeleteArtifactAlert: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var downloadedFileURL: URL?

    // 操作相关状态
    @State private var showCancelAlert: Bool = false
    @State private var showRerunAlert: Bool = false
    @State private var showRerunFailedAlert: Bool = false
    @State private var isRefreshing: Bool = false

    // 视图模式：列表视图 / 时间线视图
    @State private var viewMode: ViewMode = .list

    enum ViewMode {
        case list      // 列表视图
        case timeline  // 时间线视图
    }

    // 旋转动画状态
    @State private var rotationAngle: Double = 0

    var body: some View {
        List {
            // 状态横幅
            statusBannerSection

            // 运行概览
            overviewSection

            // 变更文件
            changedFilesSection

            // 作业列表
            jobsSection

            // Artifacts构建产物
            artifactsSection
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("运行详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if jobs.isEmpty {
                loadJobs()
            }
            if changedFiles.isEmpty {
                loadChangedFiles()
            }
            if artifacts.isEmpty {
                loadArtifacts()
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
        .alert("重新运行失败作业", isPresented: $showRerunFailedAlert) {
            Button("重新运行") {
                rerunFailedJobs()
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("确定只重新运行失败的作业吗？")
        }
        .alert("删除构建产物", isPresented: $showDeleteArtifactAlert) {
            Button("删除", role: .destructive) {
                if let artifact = artifactToDelete {
                    deleteArtifact(artifact)
                }
            }
            Button("返回", role: .cancel) {}
        } message: {
            if let artifact = artifactToDelete {
                Text("确定要删除构建产物「\(artifact.name)」吗？此操作不可恢复。")
            } else {
                Text("确定要删除此构建产物吗？")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - 状态横幅

    private var statusBannerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // 状态图标和名称
                HStack {
                    ZStack {
                        if run.status == "in_progress" {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.largeTitle)
                                .foregroundColor(Color(run.statusColor))
                                .rotationEffect(.degrees(rotationAngle))
                                .onAppear {
                                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                        rotationAngle = 360
                                    }
                                }
                        } else if run.status == "queued" || run.status == "pending" {
                            Image(systemName: "clock")
                                .font(.largeTitle)
                                .foregroundColor(Color(run.statusColor))
                                .opacity(0.5 + 0.5 * sin(rotationAngle / 180 * .pi))
                                .onAppear {
                                    withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                        rotationAngle = 360
                                    }
                                }
                        } else {
                            Image(systemName: run.statusIcon)
                                .font(.largeTitle)
                                .foregroundColor(Color(run.statusColor))
                        }
                    }
                    .frame(width: 40)  // 视图宽度40pt，控制组件水平尺寸

                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("运行 #\(run.runNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // 状态标签和操作按钮
                HStack {
                    Text(run.statusDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(run.statusColor))
                        .padding(.horizontal, 12)  // 水平内边距12pt，控制左右留白间距
                        .padding(.vertical, 4)  // 垂直内边距4pt，控制上下留白间距
                        .background(Color(run.statusColor).opacity(0.1))
                        .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度

                    Spacer()

                    // 操作按钮
                    if run.status == "in_progress" || run.status == "queued" {
                        Button(action: {
                            showCancelAlert = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("取消")
                                .foregroundColor(.red)
                        }
                    }

                    if run.status == "completed" {
                        Button(action: {
                            showRerunAlert = true
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("重跑")
                                .foregroundColor(.blue)
                        }

                        if run.conclusion == "failure" {
                            Button(action: {
                                showRerunFailedAlert = true
                            }) {
                                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                Text("重跑失败")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
        }
    }

    // MARK: - 运行概览

    private var overviewSection: some View {
        Section("运行概览") {
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
    }

    // MARK: - 变更文件

    private var changedFilesSection: some View {
        Section("变更文件 (\(changedFiles.count))") {
            if isLoadingFiles && changedFiles.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if let error = filesError, changedFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        loadChangedFiles()
                    }
                    .font(.caption)
                }
                .padding(.vertical)
                .listRowSeparator(.hidden)
            } else if changedFiles.isEmpty {
                Text("暂无变更文件")
                    .foregroundColor(.secondary)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(changedFiles) { file in
                    NavigationLink(destination: DiffView(owner: owner, repo: repo, changedFile: file, branch: run.headBranch)) {
                        HStack(spacing: 12) {
                            Image(systemName: file.statusIcon)
                                .foregroundColor(file.statusColor)
                                .frame(width: 20)  // 视图宽度20pt，控制组件水平尺寸

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.shortFilename)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if !file.filePath.isEmpty {
                                    Text(file.filePath)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            // 变更统计
                            HStack(spacing: 6) {
                                Text("+\(file.additions)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text("-\(file.deletions)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))  // 字体大小10pt，控制文字显示尺寸
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 2)  // 垂直内边距2pt，控制上下留白间距
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - 作业列表

    private var jobsSection: some View {
        Section {
            // 视图模式切换
            Picker("视图模式", selection: $viewMode) {
                Label("列表", systemImage: "list.bullet").tag(ViewMode.list)
                Label("时间线", systemImage: "timeline.selection").tag(ViewMode.timeline)
            }
            .pickerStyle(SegmentedPickerStyle())
            .listRowSeparator(.hidden)
            .padding(.bottom, 4)  // 底部内边距4pt，控制下方留白间距

            if viewMode == .list {
                // 列表视图
                if isLoadingJobs && jobs.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("加载作业中...")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if let error = jobsError, jobs.isEmpty {
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
            } else {
                // 时间线视图
                if isLoadingJobs && jobs.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("加载作业中...")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if let error = jobsError, jobs.isEmpty {
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
                    // 每个作业显示一个时间线
                    ForEach(jobs) { job in
                        VStack(alignment: .leading, spacing: 8) {
                            // 作业标题
                            HStack {
                                Image(systemName: job.statusIcon)
                                    .foregroundColor(Color(job.statusColor))
                                Text(job.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(job.statusDisplay)
                                    .font(.caption2)
                                    .foregroundColor(Color(job.statusColor))
                            }
                            .padding(.horizontal, 4)  // 水平内边距4pt，控制左右留白间距

                            // 时间线视图
                            JobTimelineView(job: job) { stepIndex in
                                // 点击步骤跳转到日志视图
                                // 这里可以传递步骤索引，在日志视图中定位到对应步骤
                            }
                            .frame(height: min(CGFloat((job.steps?.count ?? 1) * 70), 400))
                            .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度
                        }
                        .padding(.vertical, 4)  // 垂直内边距4pt，控制上下留白间距
                        .listRowSeparator(.hidden)
                    }
                }
            }
        } header: {
            Text("作业 (\(jobs.count))")
        }
    }

    // MARK: - Artifacts构建产物

    private var artifactsSection: some View {
        Section("构建产物 (\(artifacts.count))") {
            if isLoadingArtifacts && artifacts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if let error = artifactsError, artifacts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        loadArtifacts()
                    }
                    .font(.caption)
                }
                .padding(.vertical)
                .listRowSeparator(.hidden)
            } else if artifacts.isEmpty {
                Text("暂无构建产物")
                    .foregroundColor(.secondary)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(artifacts) { artifact in
                    HStack(spacing: 12) {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)  // 视图宽度20pt，控制组件水平尺寸

                        VStack(alignment: .leading, spacing: 2) {
                            Text(artifact.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(artifact.sizeDisplay)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("·")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(artifact.createdDisplay)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                // 过期时间
                                if let expiresAt = artifact.expiresAt {
                                    Text("·")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "clock")
                                        .font(.system(size: 8))  // 字体大小8pt，控制文字显示尺寸
                                        .foregroundColor(.orange)
                                    Text("过期: \(日期工具.相对时间(fromISO: expiresAt))")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                                // 已过期标记
                                if artifact.expired {
                                    Text("已过期")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)  // 水平内边距4pt，控制左右留白间距
                                        .padding(.vertical, 1)  // 垂直内边距1pt，控制上下留白间距
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(3)  // 圆角半径3pt，控制视图边角圆润程度
                                }
                            }
                        }

                        Spacer()

                        // 操作按钮
                        HStack(spacing: 12) {
                            // 下载按钮
                            if downloadingArtifactId == artifact.id {
                                ProgressView()
                                    .scaleEffect(0.8)  // 缩放比例0.8倍，控制视图整体放大缩小
                            } else {
                                Button(action: {
                                    downloadArtifact(artifact)
                                }) {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            // 删除按钮
                            if deletingArtifactId == artifact.id {
                                ProgressView()
                                    .scaleEffect(0.8)  // 缩放比例0.8倍，控制视图整体放大缩小
                            } else {
                                Button(action: {
                                    showDeleteArtifactAlert = true
                                    artifactToDelete = artifact
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 2)  // 垂直内边距2pt，控制上下留白间距
                }
            }
        }
    }

    // MARK: - 详情行视图

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))  // 字体大小14pt，控制文字显示尺寸
                .foregroundColor(.secondary)
                .frame(width: 20)  // 视图宽度20pt，控制组件水平尺寸

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
        .padding(.vertical, 2)  // 垂直内边距2pt，控制上下留白间距
    }

    // MARK: - 数据加载

    private func loadJobs(completion: (() -> Void)? = nil) {
        isLoadingJobs = true
        jobsError = nil

        GitHubAPI.shared.getWorkflowJobs(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                isLoadingJobs = false
                isRefreshing = false
                switch result {
                case .success(let jobs):
                    self.jobs = jobs
                case .failure(let error):
                    self.jobsError = "加载作业失败: \(error.localizedDescription)"
                }
                completion?()
            }
        }
    }

    private func loadChangedFiles(completion: (() -> Void)? = nil) {
        isLoadingFiles = true
        filesError = nil

        GitHubAPI.shared.getCommitFiles(owner: owner, repo: repo, sha: run.headSha) { result in
            DispatchQueue.main.async {
                isLoadingFiles = false
                switch result {
                case .success(let files):
                    self.changedFiles = files
                case .failure(let error):
                    self.filesError = "加载变更文件失败: \(error.localizedDescription)"
                }
                completion?()
            }
        }
    }

    private func loadArtifacts(completion: (() -> Void)? = nil) {
        isLoadingArtifacts = true
        artifactsError = nil

        GitHubAPI.shared.getRunArtifacts(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                isLoadingArtifacts = false
                switch result {
                case .success(let artifacts):
                    self.artifacts = artifacts
                case .failure(let error):
                    self.artifactsError = "加载构建产物失败: \(error.localizedDescription)"
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
                    refreshRun()
                    loadJobs()
                case .failure(let error):
                    jobsError = "取消运行失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func rerunRun() {
        GitHubAPI.shared.rerunWorkflowRun(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    refreshRun()
                    loadJobs()
                case .failure(let error):
                    jobsError = "重新运行失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func rerunFailedJobs() {
        GitHubAPI.shared.rerunFailedJobs(owner: owner, repo: repo, runId: run.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    refreshRun()
                    loadJobs()
                case .failure(let error):
                    jobsError = "重新运行失败作业失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func downloadArtifact(_ artifact: Artifact) {
        downloadingArtifactId = artifact.id

        GitHubAPI.shared.downloadArtifact(owner: owner, repo: repo, artifactId: artifact.id) { result in
            DispatchQueue.main.async {
                downloadingArtifactId = nil
                switch result {
                case .success(let fileURL):
                    downloadedFileURL = fileURL
                    showShareSheet = true
                case .failure(let error):
                    artifactsError = "下载失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteArtifact(_ artifact: Artifact) {
        deletingArtifactId = artifact.id

        GitHubAPI.shared.deleteArtifact(owner: owner, repo: repo, artifactId: artifact.id) { result in
            DispatchQueue.main.async {
                deletingArtifactId = nil
                switch result {
                case .success:
                    // 从列表中移除已删除的产物
                    artifacts.removeAll { $0.id == artifact.id }
                    artifactToDelete = nil
                case .failure(let error):
                    artifactsError = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 异步刷新方法

    private func refreshAllAsync() async {
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()

            group.enter()
            loadJobs {
                group.leave()
            }

            group.enter()
            refreshRun {
                group.leave()
            }

            group.enter()
            loadChangedFiles {
                group.leave()
            }

            group.enter()
            loadArtifacts {
                group.leave()
            }

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
    @State private var rotationAngle: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            ZStack {
                if job.status == "in_progress" {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                        .foregroundColor(Color(job.statusColor))
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                } else if job.status == "queued" || job.status == "pending" {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundColor(Color(job.statusColor))
                        .opacity(0.5 + 0.5 * sin(rotationAngle / 180 * .pi))
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                rotationAngle = 360
                            }
                        }
                } else {
                    Image(systemName: job.statusIcon)
                        .font(.title3)
                        .foregroundColor(Color(job.statusColor))
                }
            }
            .frame(width: 28)  // 视图宽度28pt，控制组件水平尺寸

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

                if job.conclusion == "failure", let exitCode = job.exitCode {
                    Text("(\(exitCode))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)  // 垂直内边距4pt，控制上下留白间距
    }
}

// MARK: - 系统分享面板

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ChangedFile 扩展

extension ChangedFile {
    var statusIcon: String {
        switch status {
        case "added": return "plus.circle.fill"
        case "modified": return "pencil.circle.fill"
        case "removed": return "minus.circle.fill"
        case "renamed": return "arrow.left.arrow.right.circle.fill"
        default: return "circle.fill"
        }
    }
}
