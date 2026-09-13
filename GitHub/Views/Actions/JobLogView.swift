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
    @State private var showShareSheet: Bool = false
    @State private var exportedFileURL: URL?
    @State private var isExporting: Bool = false
    @State private var currentStatus: String = ""
    @State private var currentConclusion: String?
    @State private var refreshCount: Int = 0
    @State private var lastRefreshTime: Date?

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
                    exportLogs()
                }) {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(logs.isEmpty)
                Button(action: {
                    loadLogs()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        )
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .onAppear {
            // 初始化当前状态
            currentStatus = job.status
            currentConclusion = job.conclusion

            if logs.isEmpty {
                loadLogs()
            }
            // 如果作业进行中，启动自动刷新
            if currentStatus == "in_progress" || currentStatus == "queued" {
                isAutoRefreshing = true
            }
            // 如果作业失败，自动滚动到失败步骤
            if currentConclusion == "failure" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollToFailedStep()
                }
            }
        }
        .onReceive(autoRefreshTimer) { _ in
            // 自动刷新日志（仅进行中时）
            if isAutoRefreshing && (currentStatus == "in_progress" || currentStatus == "queued") {
                loadLogs(silent: true)
            }
        }
        .onDisappear {
            isAutoRefreshing = false
        }
    }

    // MARK: - 作业信息头部

    private var jobInfoHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: currentStatusIcon)
                    .foregroundColor(currentStatusColor)
                Text(job.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 6) {
                    Text(currentStatusDisplay)
                        .font(.caption)
                        .foregroundColor(currentStatusColor)
                    // 失败时显示退出码
                    if currentConclusion == "failure" {
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

            // 自动刷新状态
            if isAutoRefreshing && (currentStatus == "in_progress" || currentStatus == "queued") {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("自动刷新中（每5秒）· 已刷新\(refreshCount)次")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    if let lastRefresh = lastRefreshTime {
                        Text("· 上次刷新: \(Self.formatRefreshTime(lastRefresh))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - 当前状态计算属性

    private var currentStatusIcon: String {
        switch currentStatus {
        case "completed":
            switch currentConclusion {
            case "success": return "checkmark.circle.fill"
            case "failure": return "xmark.circle.fill"
            case "cancelled": return "xmark.circle"
            default: return "circle"
            }
        case "in_progress": return "hourglass"
        case "queued": return "clock"
        default: return "circle"
        }
    }

    private var currentStatusColor: Color {
        switch currentStatus {
        case "completed":
            switch currentConclusion {
            case "success": return .green
            case "failure": return .red
            case "cancelled": return .gray
            default: return .gray
            }
        case "in_progress": return .blue
        case "queued": return .orange
        default: return .gray
        }
    }

    private var currentStatusDisplay: String {
        switch currentStatus {
        case "completed":
            switch currentConclusion {
            case "success": return "成功"
            case "failure": return "失败"
            case "cancelled": return "已取消"
            default: return "已完成"
            }
        case "in_progress": return "进行中"
        case "queued": return "排队中"
        default: return currentStatus
        }
    }

    private static func formatRefreshTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
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
        refreshCount += 1
        lastRefreshTime = Date()

        GitHubAPI.shared.getJobLogs(owner: owner, repo: repo, jobId: job.id, logsUrl: job.logsUrl) { result in
            DispatchQueue.main.async {
                if !silent {
                    isLoading = false
                }
                switch result {
                case .success(let logs):
                    self.logs = logs
                    // 从日志中解析退出码
                    self.parsedExitCode = Self.parseExitCode(from: logs)
                    // 如果日志非空，说明作业可能已完成，更新状态
                    if !logs.isEmpty {
                        // 检查日志中是否包含完成标志
                        if logs.contains("##[endgroup]") || logs.contains("Process completed") || logs.contains("BUILD_EXIT_CODE") {
                            // 作业可能已完成，但我们无法确定状态，保持当前状态
                        }
                    }
                case .failure(let error):
                    let nsError = error as NSError
                    // 处理404错误：作业日志可能还不可用
                    if nsError.code == 404 {
                        if self.logs.isEmpty {
                            self.errorMessage = "作业日志暂不可用，作业可能仍在初始化中，请稍后重试"
                        }
                        // 404不停止自动刷新，继续尝试
                    } else {
                        self.errorMessage = "加载日志失败: \(error.localizedDescription)"
                        // 其他错误停止自动刷新
                        if self.currentStatus == "in_progress" || self.currentStatus == "queued" {
                            // 保持自动刷新，可能是临时错误
                        }
                    }
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

    // MARK: - 导出日志

    private func exportLogs() {
        guard !logs.isEmpty else { return }
        isExporting = true

        // 生成文件名：作业名_时间戳.log
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let safeJobName = job.name.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeJobName)_\(timestamp).log"

        // 写入临时文件
        let fileManager = FileManager.default
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)

        do {
            // 添加日志头部信息
            var exportContent = "=== GitHub Actions 作业日志导出 ===\n"
            exportContent += "作业名称: \(job.name)\n"
            exportContent += "作业ID: \(job.id)\n"
            exportContent += "状态: \(job.statusDisplay)\n"
            if let conclusion = job.conclusion {
                exportContent += "结果: \(conclusion)\n"
            }
            if let exitCode = job.exitCode ?? parsedExitCode {
                exportContent += "退出码: \(exitCode)\n"
            }
            exportContent += "导出时间: \(Date())\n"
            exportContent += "====================================\n\n"
            exportContent += logs

            try exportContent.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedFileURL = fileURL
            showShareSheet = true
        } catch {
            errorMessage = "导出失败: \(error.localizedDescription)"
        }

        isExporting = false
    }
}
