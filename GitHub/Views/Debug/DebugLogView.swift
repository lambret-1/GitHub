import SwiftUI
import UIKit

// ==============================================================================
// DebugLogView 调试日志查看器（修复优化版）
// 功能：在APP内查看DebugLogger记录的日志，支持搜索、按标签/级别过滤、统计、导出
// 位置：Views/Debug，从"我的"页面进入
// ==============================================================================

struct DebugLogView: View {

    // MARK: - 行模型

    private struct DisplayLine: Identifiable {
        let id: Int          // 原始行号（稳定，避免过滤重排导致整表重建）
        let text: String
        let level: String?   // 预先解析好的级别，供 LogLineView 着色
    }

    // MARK: - 状态属性

    @State private var logContent: String = ""
    @State private var displayLines: [DisplayLine] = []
    @State private var levelCounts: [String: Int] = [:]
    @State private var allTags: [String] = ["全部"]

    @State private var selectedTag: String = "全部"
    @State private var selectedLevel: String = "全部"
    @State private var searchText: String = ""

    @State private var showClearConfirm: Bool = false
    @State private var autoScroll: Bool = true
    @State private var logFileSize: Int64 = 0
    @State private var isLoading: Bool = false

    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL?
    @State private var showExportError: Bool = false
    @State private var exportErrorMessage: String = ""

    /// 仅在「加载/刷新/开启自动滚动」时自增，触发滚动到底部
    @State private var scrollToBottomToken: Int = 0
    /// 搜索防抖任务
    @State private var searchDebounceTask: Task<Void, Never>?

    // MARK: - 派生数据

    private var errorCount: Int {
        (levelCounts["ERROR"] ?? 0) + (levelCounts["CRASH"] ?? 0)
    }

    private var allLevels: [String] {
        ["全部", "DEBUG", "INFO", "WARNING", "ERROR", "CRASH"]
    }

    // MARK: - 视图主体

    var body: some View {
        VStack(spacing: 0) {
            searchAndStatsBar
            filterSelector
            logContentArea
            bottomBar
        }
        .navigationTitle("调试日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    autoScroll.toggle()
                    if autoScroll {
                        // 打开自动滚动：立即滚到底部
                        scrollToBottomToken += 1
                    }
                } label: {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .foregroundColor(autoScroll ? .blue : .gray)
                }
                .accessibilityLabel(autoScroll ? "关闭自动滚动" : "开启自动滚动")
            }
        }
        .onAppear {
            loadLogs()
        }
        .onDisappear {
            searchDebounceTask?.cancel()
            cleanupExportFile()
        }
        .onChangeCompat(of: searchText) { _ in
            scheduleSearchRebuild()
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
        .alert("导出失败", isPresented: $showExportError) {
            Button("好", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
        .sheet(isPresented: $showExportSheet, onDismiss: {
            cleanupExportFile()
        }) {
            if let url = exportURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    // MARK: - 搜索 + 统计合并栏

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
                    Button {
                        searchText = ""
                    } label: {
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

            // 精简统计（全部基于「过滤后」口径，和列表一致）
            HStack(spacing: 8) {
                statItemCompact(label: "条", value: "\(displayLines.count)", color: .primary)
                statItemCompact(label: "错", value: "\(errorCount)", color: .red)
                Text(Self.formatFileSize(logFileSize))
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

    // MARK: - 标签 + 级别合并选择栏

    private var filterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // 标签选择（切换标签需要重新读文件）
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        guard selectedTag != tag else { return }
                        selectedTag = tag
                        loadLogs()
                    } label: {
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

                // 级别选择（"全部"用漏斗图标，避免与标签"全部"语义混淆）
                ForEach(allLevels, id: \.self) { level in
                    Button {
                        guard selectedLevel != level else { return }
                        selectedLevel = level
                        rebuild()   // 级别切换只走内存过滤，无需重新读文件
                    } label: {
                        if level == "全部" {
                            Image(systemName: selectedLevel == "全部"
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 12))
                                .foregroundColor(selectedLevel == "全部" ? .blue : .gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            Text(level)
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedLevel == level
                                            ? levelColor(level).opacity(0.15)
                                            : Color.gray.opacity(0.1))
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
        case "DEBUG":   return .gray
        case "INFO":    return .blue
        case "WARNING": return .orange
        case "ERROR":   return .red
        case "CRASH":   return .purple
        default:        return .primary
        }
    }

    // MARK: - 日志内容区域

    private var logContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if displayLines.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(isLoading ? "正在加载…" : "暂无匹配的日志记录")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(displayLines) { item in
                            LogLineView(text: item.text, level: item.level)
                                .id(item.id)
                        }
                    }
                    .padding(12)

                    // 固定底部锚点，保证 scrollTo 一定命中（不受空行影响）
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .onChangeCompat(of: scrollToBottomToken) { _ in
                guard autoScroll else { return }
                // 等一帧让布局完成，再滚动
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                loadLogs()
            } label: {
                actionLabel(icon: "arrow.clockwise", title: "刷新", color: .blue)
            }
            .disabled(isLoading)

            Button {
                UIPasteboard.general.string = displayLines.map(\.text).joined(separator: "\n")
            } label: {
                actionLabel(icon: "doc.on.doc", title: "复制", color: .green)
            }
            .disabled(displayLines.isEmpty)

            Button {
                prepareExport()
            } label: {
                actionLabel(icon: "square.and.arrow.up", title: "导出", color: .orange)
            }
            .disabled(displayLines.isEmpty)

            Button {
                showClearConfirm = true
            } label: {
                actionLabel(icon: "trash", title: "清理", color: .red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    private func actionLabel(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(8)
    }

    // MARK: - 数据加载

    private func loadLogs() {
        let tag = selectedTag
        isLoading = true
        Task { @MainActor in
            let result = await Self.readLogsAsync(tag: tag)
            self.logContent = result.content
            self.logFileSize = result.size
            self.allTags = ["全部"] + result.tags
            self.isLoading = false
            self.rebuild()
            self.scrollToBottomToken += 1   // 加载完成后滚到底部
        }
    }

    private static func readLogsAsync(
        tag: String
    ) async -> (content: String, size: Int64, tags: [String]) {
        await Task.detached(priority: .userInitiated) {
            let content = (tag == "全部")
                ? DebugLogger.shared.readTodayLogs()
                : DebugLogger.shared.readLogs(withTag: tag)
            return (content,
                    DebugLogger.shared.getLogFileSize(),
                    DebugLogger.shared.getAllTags())
        }.value
    }

    /// 重新计算过滤结果（级别 + 搜索），一次遍历同时得出列表和统计
    private func rebuild() {
        let lines = logContent.components(separatedBy: .newlines)
        var filtered: [DisplayLine] = []
        var counts: [String: Int] = [:]
        filtered.reserveCapacity(lines.count)

        let levelFilter = selectedLevel
        let query = searchText

        for (index, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            let level = Self.parseLevel(line)

            if levelFilter != "全部", level != levelFilter { continue }
            if !query.isEmpty, !line.localizedCaseInsensitiveContains(query) { continue }

            filtered.append(DisplayLine(id: index, text: line, level: level))
            if let level { counts[level, default: 0] += 1 }
        }

        displayLines = filtered
        levelCounts = counts
    }

    private func scheduleSearchRebuild() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s 防抖
            guard !Task.isCancelled else { return }
            rebuild()
        }
    }

    /// 只解析行首区域，避免正文里的 "[ERROR]" 误判整行着色
    private static func parseLevel(_ line: String) -> String? {
        let head = line.prefix(120)
        for level in ["DEBUG", "INFO", "WARNING", "ERROR", "CRASH"] {
            if head.contains("[\(level)]") { return level }
        }
        return nil
    }

    // MARK: - 导出

    private func prepareExport() {
        let text = displayLines.map(\.text).joined(separator: "\n")
        guard !text.isEmpty else {
            exportErrorMessage = "当前没有可导出的日志内容。"
            showExportError = true
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "debug_logs_\(formatter.string(from: Date())).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            exportURL = fileURL
            showExportSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }

    private func cleanupExportFile() {
        guard let url = exportURL else { return }
        try? FileManager.default.removeItem(at: url)
        exportURL = nil
    }

    // MARK: - 文件大小格式化

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    private static func formatFileSize(_ size: Int64) -> String {
        byteFormatter.string(fromByteCount: size)
    }
}

// MARK: - 日志行视图

struct LogLineView: View {
    let text: String
    let level: String?

    private var textColor: Color {
        switch level {
        case "DEBUG":   return .gray
        case "INFO":    return .primary
        case "WARNING": return .orange
        case "ERROR":   return .red
        case "CRASH":   return .purple
        default:        return .primary
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)
    }
}

// MARK: - UIActivityViewController 封装

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - onChange 兼容层（消除 iOS 17 废弃警告，兼容 iOS 16 及以下）

private extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (V) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}