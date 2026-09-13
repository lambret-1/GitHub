import SwiftUI

// MARK: - 作业日志视图（优化版：步骤定位+自动滚动）

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
    @State private var autoScrollToBottom: Bool = true
    @State private var stepRanges: [(name: String, range: Range<String.Index>)] = []

    // 滚动代理
    @State private var scrollProxy: ScrollViewProxy?

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

            // 自动滚动开关
            autoScrollBar

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
            // 如果作业失败，自动滚动到失败步骤
            if job.conclusion == "failure" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollToFailedStep()
                }
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

    // MARK: - 自动滚动开关

    private var autoScrollBar: some View {
        HStack {
            Toggle(isOn: $autoScrollToBottom) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.caption)
                    Text("自动滚动到底部")
                        .font(.caption)
                }
            }
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            Spacer()
            if autoScrollToBottom {
                Text("自动滚动已开启")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6).opacity(0.5))
    }

    // MARK: - 步骤列表

    private func stepsSection(steps: [JobStep]) -> some View {
        DisclosureGroup(isExpanded: $showSteps) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        Button(action: {
                            selectedStepIndex = index
                            scrollToStep(index)
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
                if job.conclusion == "failure" {
                    Text("点击失败步骤定位")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
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

                    // 日志文本视图（带步骤定位）
                    ScrollViewReader { proxy in
                        ScrollView {
                            if searchText.isEmpty {
                                // 普通日志显示
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(logs.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                                        HStack(alignment: .top, spacing: 0) {
                                            // 行号
                                            Text("\(index + 1)")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.gray)
                                                .frame(width: 35, alignment: .trailing)
                                                .padding(.trailing, 6)
                                            // 日志内容
                                            Text(line)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(colorForLogLine(line))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 0.5)
                                        .background(isErrorLine(line) ? Color.red.opacity(0.1) : (index % 2 == 0 ? Color(.systemBackground) : Color(.systemGray6).opacity(0.3)))
                                        .id(index)
                                    }
                                    // 底部锚点
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom")
                                }
                                .padding(.vertical, 4)
                                .onAppear {
                                    scrollProxy = proxy
                                    // 自动滚动到底部
                                    if autoScrollToBottom {
                                        DispatchQueue.main.async {
                                            withAnimation {
                                                proxy.scrollTo("bottom", anchor: .bottom)
                                            }
                                        }
                                    }
                                }
                                .onChange(of: logs) { _ in
                                    // 日志更新时自动滚动到底部
                                    if autoScrollToBottom {
                                        DispatchQueue.main.async {
                                            withAnimation {
                                                proxy.scrollTo("bottom", anchor: .bottom)
                                            }
                                        }
                                    }
                                }
                            } else {
                                // 搜索高亮显示
                                highlightedLogs
                            }
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
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if line.localizedCaseInsensitiveContains(searchText) {
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(index + 1)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(width: 35, alignment: .trailing)
                            .padding(.trailing, 6)
                        Text(line)
                            .font(.system(size: 9, design: .monospaced))
                            .background(Color.yellow.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 0.5)
                    .background(Color.yellow.opacity(0.1))
                }
            }
        }
        .padding(.vertical, 4)
        .textSelection(.enabled)
    }

    // MARK: - 日志行颜色

    private func colorForLogLine(_ line: String) -> Color {
        let lowercased = line.lowercased()
        if lowercased.contains("error") || lowercased.contains("错误") || lowercased.contains("失败") {
            return .red
        }
        if lowercased.contains("warning") || lowercased.contains("警告") {
            return .orange
        }
        if lowercased.contains("success") || lowercased.contains("成功") || lowercased.contains("✅") {
            return .green
        }
        if line.hasPrefix("##[group]") || line.hasPrefix("::group::") {
            return .blue
        }
        if line.hasPrefix("##[endgroup]") || line.hasPrefix("::endgroup::") {
            return .purple
        }
        return .primary
    }

    // MARK: - 判断是否为错误行

    private func isErrorLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("error:") ||
               lowercased.contains("fatal error") ||
               lowercased.contains("build failed") ||
               lowercased.contains("编译失败") ||
               lowercased.contains("::error::")
    }

    // MARK: - 滚动到指定步骤

    private func scrollToStep(_ index: Int) {
        guard let steps = job.steps, index < steps.count else { return }
        let stepName = steps[index].name

        // 在日志中查找步骤名称的位置
        let lines = logs.components(separatedBy: .newlines)
        for (lineIndex, line) in lines.enumerated() {
            if line.contains(stepName) || line.contains("##[group]") && line.contains(stepName) {
                DispatchQueue.main.async {
                    withAnimation {
                        scrollProxy?.scrollTo(lineIndex, anchor: .top)
                    }
                }
                return
            }
        }
    }

    // MARK: - 滚动到失败步骤

    private func scrollToFailedStep() {
        guard let steps = job.steps else { return }

        // 找到第一个失败的步骤
        for (index, step) in steps.enumerated() {
            if step.conclusion == "failure" {
                selectedStepIndex = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scrollToStep(index)
                }
                return
            }
        }
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
