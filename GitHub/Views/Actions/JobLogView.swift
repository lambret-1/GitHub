import SwiftUI

// MARK: - 作业日志视图（重做版）

struct JobLogView: View {
    let owner: String
    let repo: String
    let job: WorkflowJob

    @State private var logs: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSteps: Bool = true
    @State private var selectedStepIndex: Int? = nil
    @State private var parsedExitCode: Int?
    @State private var isAutoRefreshing: Bool = false
    @State private var searchText: String = ""
    @State private var showSearch: Bool = false

    // 自动刷新定时器
    private let autoRefreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // 作业信息头部
            jobInfoHeader

            // 搜索栏
            if showSearch {
                searchBar
            }

            // 步骤列表（可折叠）
            if let steps = job.steps, !steps.isEmpty {
                stepsSection(steps: steps)
            }

            // 日志内容
            logContentSection
        }
        .navigationTitle("作业日志")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            HStack(spacing: 16) {
                Button(action: {
                    showSearch.toggle()
                }) {
                    Image(systemName: "magnifyingglass")
                }
                Button(action: {
                    loadLogs()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        )
        .onAppear {
            if logs.isEmpty {
                loadLogs()
            }
            // 如果作业进行中，启动自动刷新
            if job.status == "in_progress" {
                isAutoRefreshing = true
            }
        }
        .onReceive(autoRefreshTimer) { _ in
            // 自动刷新日志（仅进行中时）
            if isAutoRefreshing && job.status == "in_progress" {
                loadLogs(silent: true)
            }
        }
        .onDisappear {
            isAutoRefreshing = false
        }
    }

    // MARK: - 作业信息头部

    private var jobInfoHeader: some View {
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
                    let displayExitCode = job.exitCode ?? parsedExitCode
                    if let exitCode = displayExitCode {
                        Text("退出码: \(exitCode)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("退出码: 解析中...")
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
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索日志...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - 步骤列表

    private func stepsSection(steps: [JobStep]) -> some View {
        DisclosureGroup(isExpanded: $showSteps) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        Button(action: {
                            if selectedStepIndex == index {
                                selectedStepIndex = nil
                            } else {
                                selectedStepIndex = index
                            }
                        }) {
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
                            .background(selectedStepIndex == index ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedStepIndex == index ? Color.blue : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
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
        .background(Color(.systemGray6))
    }

    // MARK: - 日志内容

    private var logContentSection: some View {
        Group {
            if isLoading && logs.isEmpty {
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
                            let displayExitCode = job.exitCode ?? parsedExitCode
                            if let exitCode = displayExitCode {
                                Text("退出码: \(exitCode)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(4)
                            } else {
                                Text("退出码: 解析中...")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                    }

                    // 自动刷新提示
                    if isAutoRefreshing && job.status == "in_progress" {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("日志自动刷新中（每5秒）")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.05))
                    }

                    // 日志文本视图
                    ScrollView {
                        if searchText.isEmpty {
                            Text(logs)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .textSelection(.enabled)
                        } else {
                            // 搜索高亮显示
                            highlightedLogs
                        }
                    }
                    .background(Color(.systemBackground))
                }
            }
        }
    }

    // MARK: - 搜索高亮日志

    private var highlightedLogs: some View {
        let lines = logs.components(separatedBy: .newlines)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.localizedCaseInsensitiveContains(searchText) {
                    Text(line)
                        .font(.system(size: 10, design: .monospaced))
                        .background(Color.yellow.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                }
            }
        }
        .padding(.vertical, 8)
        .textSelection(.enabled)
    }

    // MARK: - 数据加载

    private func loadLogs(silent: Bool = false) {
        if !silent {
            isLoading = true
        }
        errorMessage = nil

        GitHubAPI.shared.getJobLogs(owner: owner, repo: repo, jobId: job.id) { result in
            DispatchQueue.main.async {
                if !silent {
                    isLoading = false
                }
                switch result {
                case .success(let logs):
                    self.logs = logs
                    // 从日志中解析退出码
                    self.parsedExitCode = Self.parseExitCode(from: logs)
                case .failure(let error):
                    self.errorMessage = "加载日志失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 从日志中解析退出码

    private static func parseExitCode(from logs: String) -> Int? {
        // 匹配多种退出码格式
        let patterns = [
            "退出码[:：]\\s*(\\d+)",
            "exit code[:：]?\\s*(\\d+)",
            "EXIT CODE[:：]?\\s*(\\d+)",
            "BUILD_EXIT_CODE[=:]\\s*(\\d+)",
            "Command failed with exit code (\\d+)",
            "xcodebuild.*exit (\\d+)",
            "error:\\s*.*exit (\\d+)",
            "Process completed with exit code (\\d+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(logs.startIndex..., in: logs)
                if let match = regex.firstMatch(in: logs, options: [], range: range),
                   let codeRange = Range(match.range(at: 1), in: logs) {
                    return Int(logs[codeRange])
                }
            }
        }

        // 如果没有找到明确的退出码，尝试查找最后一个非零退出码
        let lines = logs.components(separatedBy: .newlines)
        for line in lines.reversed() {
            if let range = line.range(of: #"\d+"#, options: .regularExpression),
               let code = Int(line[range]), code > 0 && code < 256 {
                if line.lowercased().contains("error") ||
                   line.lowercased().contains("fail") ||
                   line.lowercased().contains("exit") ||
                   line.contains("错误") ||
                   line.contains("失败") ||
                   line.contains("退出") {
                    return code
                }
            }
        }

        return nil
    }
}
