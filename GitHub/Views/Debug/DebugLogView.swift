import SwiftUI

// ==============================================================================
// DebugLogView 调试日志查看器（优化版）
// 功能：在APP内查看DebugLogger记录的日志，支持搜索、按标签/级别过滤、统计、导出
// 位置：Views/Debug，从"我的"页面进入
// 设计原则：功能完善，操作便捷，方便快速定位问题
// ==============================================================================

struct DebugLogView: View {
    // MARK: - 状态属性

    @State private var logContent: String = ""
    @State private var selectedTag: String = "全部"
    @State private var selectedLevel: String = "全部"
    @State private var searchText: String = ""
    @State private var showClearConfirm: Bool = false
    @State private var autoScroll: Bool = true
    @State private var logFileSize: Int64 = 0
    @State private var logCount: Int = 0
    @State private var showExportSheet: Bool = false

    // MARK: - 计算属性

    private var allTags: [String] {
        ["全部"] + DebugLogger.shared.getAllTags()
    }

    private var allLevels: [String] {
        ["全部", "DEBUG", "INFO", "WARNING", "ERROR", "CRASH"]
    }

    /// 过滤后的日志内容
    private var filteredLogs: String {
        var result = logContent

        // 按级别过滤
        if selectedLevel != "全部" {
            let lines = result.components(separatedBy: .newlines)
            let filtered = lines.filter { $0.contains("[\(selectedLevel)]") }
            result = filtered.joined(separator: "\n")
        }

        // 按搜索关键词过滤
        if !searchText.isEmpty {
            let lines = result.components(separatedBy: .newlines)
            let filtered = lines.filter { $0.localizedCaseInsensitiveContains(searchText) }
            result = filtered.joined(separator: "\n")
        }

        return result
    }

    /// 各级别日志数量统计
    private var levelStats: [String: Int] {
        var stats: [String: Int] = [:]
        let lines = logContent.components(separatedBy: .newlines)
        for line in lines {
            for level in ["DEBUG", "INFO", "WARNING", "ERROR", "CRASH"] {
                if line.contains("[\(level)]") {
                    stats[level, default: 0] += 1
                    break
                }
            }
        }
        return stats
    }

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            // 搜索+统计合并栏（减少顶部高度）
            searchAndStatsBar

            // 标签+级别合并选择栏
            filterSelector

            // 日志内容区域
            logContentArea

            // 底部操作栏
            bottomBar
        }
        .navigationTitle("调试日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    autoScroll.toggle()
                }) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .foregroundColor(autoScroll ? .blue : .gray)
                }
            }
        }
        .onAppear {
            loadLogs()
        }
        .alert("确认清理", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) { }
            Button("清理", role: .destructive) {
                DebugLogger.shared.clearTodayLogs()
                loadLogs()
            }
        } message: {
            Text("确定要清理今天的所有调试日志吗？此操作不可恢复。")
        }
        .sheet(isPresented: $showExportSheet) {
            // 分享日志文件
            ActivityViewController(activityItems: [exportLogFile()])
        }
    }

    // MARK: - 搜索+统计合并栏

    private var searchAndStatsBar: some View {
        HStack(spacing: 10) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                TextField("搜索", text: $searchText)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(6)

            Spacer()

            // 精简统计（只显示关键指标）
            HStack(spacing: 8) {
                statItemCompact(label: "总", value: "\(logCount)", color: .primary)
                statItemCompact(label: "错", value: "\((levelStats["ERROR"] ?? 0) + (levelStats["CRASH"] ?? 0))", color: .red)
                Text(formatFileSize(logFileSize))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    private func statItemCompact(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 标签+级别合并选择栏

    private var filterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // 标签选择
                ForEach(allTags, id: \.self) { tag in
                    Button(action: {
                        selectedTag = tag
                        loadLogs()
                    }) {
                        Text(tag)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTag == tag ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                            .foregroundColor(selectedTag == tag ? .blue : .primary)
                            .cornerRadius(4)
                    }
                }

                // 分隔符
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 16)

                // 级别选择（用漏斗图标表示全部级别，避免与标签"全部"重复）
                ForEach(allLevels, id: \.self) { level in
                    Button(action: {
                        selectedLevel = level
                    }) {
                        if level == "全部" {
                            Image(systemName: selectedLevel == "全部" ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 12))
                                .foregroundColor(selectedLevel == "全部" ? .blue : .gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            Text(level)
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedLevel == level ? levelColor(level).opacity(0.15) : Color.gray.opacity(0.1))
                                .foregroundColor(selectedLevel == level ? levelColor(level) : .primary)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(Color(.systemGray6))
    }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "DEBUG": return .gray
        case "INFO": return .blue
        case "WARNING": return .orange
        case "ERROR": return .red
        case "CRASH": return .purple
        default: return .primary
        }
    }

    // MARK: - 日志内容区域

    private var logContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if filteredLogs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("暂无匹配的日志记录")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(filteredLogs.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                            if !line.isEmpty {
                                LogLineView(line: line)
                                    .id(index)
                            }
                        }
                    }
                    .padding(12)
                    .onChange(of: filteredLogs) { _ in
                        if autoScroll {
                            withAnimation {
                                proxy.scrollTo(filteredLogs.components(separatedBy: .newlines).count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button(action: {
                loadLogs()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }

            Button(action: {
                UIPasteboard.general.string = filteredLogs
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("复制")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(8)
            }

            Button(action: {
                showExportSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(8)
            }

            Button(action: {
                showClearConfirm = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清理")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    // MARK: - 私有方法

    private func loadLogs() {
        if selectedTag == "全部" {
            logContent = DebugLogger.shared.readTodayLogs()
        } else {
            logContent = DebugLogger.shared.readLogs(withTag: selectedTag)
        }
        logCount = logContent.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        logFileSize = DebugLogger.shared.getLogFileSize()
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func exportLogFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "debug_logs_\(dateFormatter.string(from: Date())).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        try? filteredLogs.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

// MARK: - 日志行视图（带颜色区分）

struct LogLineView: View {
    let line: String

    private var level: String {
        if line.contains("[DEBUG]") { return "DEBUG" }
        if line.contains("[INFO]") { return "INFO" }
        if line.contains("[WARNING]") { return "WARNING" }
        if line.contains("[ERROR]") { return "ERROR" }
        if line.contains("[CRASH]") { return "CRASH" }
        return "UNKNOWN"
    }

    private var textColor: Color {
        switch level {
        case "DEBUG": return .gray
        case "INFO": return .primary
        case "WARNING": return .orange
        case "ERROR": return .red
        case "CRASH": return .purple
        default: return .primary
        }
    }

    var body: some View {
        Text(line)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)
    }
}

// MARK: - UIActivityViewController 封装（用于导出分享）

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
