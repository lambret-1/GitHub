import SwiftUI

// MARK: - 运行对比视图
// 用于对比两次工作流运行的差异，包括状态、耗时、作业、变更文件等

struct RunComparisonView: View {
    let owner: String
    let repo: String
    let run1: WorkflowRun
    let run2: WorkflowRun

    // 作业相关状态
    @State private var jobs1: [WorkflowJob] = []
    @State private var jobs2: [WorkflowJob] = []
    @State private var isLoadingJobs: Bool = false
    @State private var jobsError: String?

    // 变更文件相关状态
    @State private var files1: [ChangedFile] = []
    @State private var files2: [ChangedFile] = []
    @State private var isLoadingFiles: Bool = false
    @State private var filesError: String?

    // 当前选中的对比维度
    @State private var selectedDimension: ComparisonDimension = .overview

    enum ComparisonDimension: String, CaseIterable {
        case overview = "概览"
        case jobs = "作业对比"
        case files = "变更文件"
        case timing = "耗时分析"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 对比头部
            comparisonHeader

            // 维度选择器
            dimensionSelector

            // 对比内容
            ScrollView {
                LazyVStack(spacing: 12) {
                    switch selectedDimension {
                    case .overview:
                        overviewComparison
                    case .jobs:
                        jobsComparison
                    case .files:
                        filesComparison
                    case .timing:
                        timingComparison
                    }
                }
                .padding()
            }
        }
        .navigationTitle("运行对比")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadComparisonData()
        }
    }

    // MARK: - 对比头部

    private var comparisonHeader: some View {
        HStack(spacing: 8) {
            // 运行1
            runCard(run: run1, isLeft: true)

            // VS标志
            VStack {
                Text("VS")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .frame(width: 60)

            // 运行2
            runCard(run: run2, isLeft: false)
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private func runCard(run: WorkflowRun, isLeft: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: run.statusIcon)
                    .foregroundColor(Color(run.statusColor))
                Text("#\(run.runNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text(run.name)
                .font(.subheadline)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(run.statusDisplay)
                    .font(.caption)
                    .foregroundColor(Color(run.statusColor))
                if let conclusion = run.conclusion, conclusion == "failure" {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Text(run.shortSha)
                .font(.caption2)
                .foregroundColor(.secondary)

            if let message = run.headCommit?.message {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isLeft ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - 维度选择器

    private var dimensionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ComparisonDimension.allCases, id: \.self) { dimension in
                    Button(action: {
                        selectedDimension = dimension
                    }) {
                        Text(dimension.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedDimension == dimension ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedDimension == dimension ? Color.blue : Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 概览对比

    private var overviewComparison: some View {
        VStack(spacing: 12) {
            comparisonRow(title: "状态", value1: run1.statusDisplay, value2: run2.statusDisplay, color1: Color(run1.statusColor), color2: Color(run2.statusColor))
            comparisonRow(title: "结论", value1: run1.conclusion ?? "-", value2: run2.conclusion ?? "-")
            comparisonRow(title: "分支", value1: run1.headBranch, value2: run2.headBranch)
            comparisonRow(title: "触发事件", value1: run1.eventDisplay, value2: run2.eventDisplay)
            comparisonRow(title: "触发者", value1: run1.actor?.login ?? "-", value2: run2.actor?.login ?? "-")
            comparisonRow(title: "创建时间", value1: run1.formattedCreatedAt, value2: run2.formattedCreatedAt)
            if let duration1 = run1.durationSeconds, let duration2 = run2.durationSeconds {
                comparisonRow(title: "总耗时", value1: formatDuration(duration1), value2: formatDuration(duration2), highlightDifference: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    // MARK: - 作业对比

    private var jobsComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("作业对比")
                .font(.headline)
                .fontWeight(.bold)

            if isLoadingJobs {
                HStack {
                    Spacer()
                    ProgressView("加载作业中...")
                    Spacer()
                }
            } else if let error = jobsError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // 作业数量对比
                comparisonRow(title: "作业数量", value1: "\(jobs1.count)", value2: "\(jobs2.count)")

                // 逐个作业对比
                ForEach(0..<max(jobs1.count, jobs2.count), id: \.self) { index in
                    let job1 = index < jobs1.count ? jobs1[index] : nil
                    let job2 = index < jobs2.count ? jobs2[index] : nil

                    jobComparisonRow(job1: job1, job2: job2, index: index)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private func jobComparisonRow(job1: WorkflowJob?, job2: WorkflowJob?, index: Int) -> some View {
        HStack(spacing: 8) {
            // 作业1
            VStack(alignment: .leading, spacing: 4) {
                if let job = job1 {
                    HStack {
                        Image(systemName: job.statusIcon)
                            .font(.caption)
                            .foregroundColor(Color(job.statusColor))
                        Text(job.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Text(job.statusDisplay)
                            .font(.caption2)
                            .foregroundColor(Color(job.statusColor))
                        if let duration = job.durationSeconds {
                            Text("· \(formatDuration(duration))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("无此作业")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(job1?.conclusion == "failure" ? Color.red.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(6)

            // 箭头
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.gray)

            // 作业2
            VStack(alignment: .leading, spacing: 4) {
                if let job = job2 {
                    HStack {
                        Image(systemName: job.statusIcon)
                            .font(.caption)
                            .foregroundColor(Color(job.statusColor))
                        Text(job.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Text(job.statusDisplay)
                            .font(.caption2)
                            .foregroundColor(Color(job.statusColor))
                        if let duration = job.durationSeconds {
                            Text("· \(formatDuration(duration))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("无此作业")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(job2?.conclusion == "failure" ? Color.red.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(6)
        }
    }

    // MARK: - 变更文件对比

    private var filesComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("变更文件对比")
                .font(.headline)
                .fontWeight(.bold)

            if isLoadingFiles {
                HStack {
                    Spacer()
                    ProgressView("加载变更文件中...")
                    Spacer()
                }
            } else if let error = filesError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                comparisonRow(title: "变更文件数", value1: "\(files1.count)", value2: "\(files2.count)")

                // 统计新增/修改/删除
                let stats1 = calculateFileStats(files1)
                let stats2 = calculateFileStats(files2)
                comparisonRow(title: "新增", value1: "\(stats1.added)", value2: "\(stats2.added)", color1: .green, color2: .green)
                comparisonRow(title: "修改", value1: "\(stats1.modified)", value2: "\(stats2.modified)", color1: .blue, color2: .blue)
                comparisonRow(title: "删除", value1: "\(stats1.removed)", value2: "\(stats2.removed)", color1: .red, color2: .red)

                // 代码行数变更
                let lines1 = calculateLineChanges(files1)
                let lines2 = calculateLineChanges(files2)
                comparisonRow(title: "新增行数", value1: "+\(lines1.additions)", value2: "+\(lines2.additions)", color1: .green, color2: .green)
                comparisonRow(title: "删除行数", value1: "-\(lines1.deletions)", value2: "-\(lines2.deletions)", color1: .red, color2: .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    // MARK: - 耗时分析

    private var timingComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("耗时分析")
                .font(.headline)
                .fontWeight(.bold)

            if isLoadingJobs {
                HStack {
                    Spacer()
                    ProgressView("加载作业中...")
                    Spacer()
                }
            } else {
                // 总耗时对比
                if let duration1 = run1.durationSeconds, let duration2 = run2.durationSeconds {
                    VStack(spacing: 8) {
                        Text("总耗时对比")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 12) {
                            timingBar(duration: duration1, maxDuration: max(duration1, duration2), color: .blue, label: "#\(run1.runNumber)")
                            timingBar(duration: duration2, maxDuration: max(duration1, duration2), color: .orange, label: "#\(run2.runNumber)")
                        }

                        // 耗时差异
                        let diff = duration2 - duration1
                        HStack {
                            Spacer()
                            if diff > 0 {
                                Text("运行 #\(run2.runNumber) 比 #\(run1.runNumber) 慢 \(formatDuration(diff))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if diff < 0 {
                                Text("运行 #\(run2.runNumber) 比 #\(run1.runNumber) 快 \(formatDuration(-diff))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("两次运行耗时相同")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // 各作业耗时对比
                Text("各作业耗时对比")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ForEach(0..<max(jobs1.count, jobs2.count), id: \.self) { index in
                    let job1 = index < jobs1.count ? jobs1[index] : nil
                    let job2 = index < jobs2.count ? jobs2[index] : nil

                    if let duration1 = job1?.durationSeconds, let duration2 = job2?.durationSeconds {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job1?.name ?? job2?.name ?? "未知")
                                .font(.caption)
                                .fontWeight(.medium)

                            HStack(spacing: 8) {
                                timingBar(duration: duration1, maxDuration: max(duration1, duration2), color: .blue, label: formatDuration(duration1))
                                timingBar(duration: duration2, maxDuration: max(duration1, duration2), color: .orange, label: formatDuration(duration2))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private func timingBar(duration: Int, maxDuration: Int, color: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(CGFloat(duration) / CGFloat(max(maxDuration, 1)) * geometry.size.width, 20), height: 12)
            }
            .frame(height: 12)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 通用对比行

    private func comparisonRow(title: String, value1: String, value2: String, color1: Color = .primary, color2: Color = .primary, highlightDifference: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value1)
                .font(.subheadline)
                .foregroundColor(color1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(highlightDifference && value1 != value2 ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(4)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.gray)

            Text(value2)
                .font(.subheadline)
                .foregroundColor(color2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(highlightDifference && value1 != value2 ? Color.orange.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(4)
        }
    }

    // MARK: - 数据加载

    private func loadComparisonData() {
        loadJobs()
        loadChangedFiles()
    }

    private func loadJobs() {
        isLoadingJobs = true
        jobsError = nil

        let group = DispatchGroup()

        group.enter()
        GitHubAPI.shared.getWorkflowJobs(owner: owner, repo: repo, runId: run1.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let jobs):
                    self.jobs1 = jobs
                case .failure(let error):
                    self.jobsError = "加载运行1作业失败: \(error.localizedDescription)"
                }
                group.leave()
            }
        }

        group.enter()
        GitHubAPI.shared.getWorkflowJobs(owner: owner, repo: repo, runId: run2.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let jobs):
                    self.jobs2 = jobs
                case .failure(let error):
                    self.jobsError = "加载运行2作业失败: \(error.localizedDescription)"
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isLoadingJobs = false
        }
    }

    private func loadChangedFiles() {
        isLoadingFiles = true
        filesError = nil

        let group = DispatchGroup()

        group.enter()
        GitHubAPI.shared.getCommitFiles(owner: owner, repo: repo, sha: run1.headSha) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let files):
                    self.files1 = files
                case .failure:
                    self.files1 = []
                }
                group.leave()
            }
        }

        group.enter()
        GitHubAPI.shared.getCommitFiles(owner: owner, repo: repo, sha: run2.headSha) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let files):
                    self.files2 = files
                case .failure:
                    self.files2 = []
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isLoadingFiles = false
        }
    }

    // MARK: - 辅助方法

    private func calculateFileStats(_ files: [ChangedFile]) -> (added: Int, modified: Int, removed: Int) {
        var added = 0
        var modified = 0
        var removed = 0

        for file in files {
            switch file.status {
            case "added": added += 1
            case "modified": modified += 1
            case "removed": removed += 1
            default: break
            }
        }

        return (added, modified, removed)
    }

    private func calculateLineChanges(_ files: [ChangedFile]) -> (additions: Int, deletions: Int) {
        var additions = 0
        var deletions = 0

        for file in files {
            additions += file.additions
            deletions += file.deletions
        }

        return (additions, deletions)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        } else {
            return "\(seconds / 3600)时\((seconds % 3600) / 60)分"
        }
    }
}
