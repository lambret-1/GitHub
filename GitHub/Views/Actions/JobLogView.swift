import SwiftUI

// MARK: - 日志行类型枚举
enum LogLineType {
    case normal       // 普通日志
    case groupStart   // 分组开始 (##[group] 或 ::group::)
    case groupEnd     // 分组结束 (##[endgroup] 或 ::endgroup::)
    case error        // 错误行
    case warning      // 警告行
    case success      // 成功行
}

// MARK: - 日志行模型
struct LogLine: Identifiable {
    let id = UUID()
    let lineNumber: Int       // 原始行号（从1开始）
    let content: String       // 日志内容
    let type: LogLineType     // 行类型
    var groupId: UUID?        // 所属分组ID（用于折叠）
    var isGroupHeader: Bool   // 是否是分组标题行
    var groupName: String?    // 分组名称（仅分组标题行有）
}

// MARK: - 日志分组模型
struct LogGroup: Identifiable {
    let id = UUID()
    let name: String           // 分组名称
    let startLine: Int        // 开始行号
    var endLine: Int          // 结束行号
    var isCollapsed: Bool     // 是否折叠
    var lineCount: Int { endLine - startLine + 1 }
}

// MARK: - 搜索匹配结果模型
struct SearchMatch: Identifiable {
    let id = UUID()
    let lineIndex: Int        // 在可见行数组中的索引
    let lineNumber: Int       // 原始行号
    let range: Range<String.Index>  // 匹配范围
}

// MARK: - 作业日志视图（性能优化版：虚拟滚动+增量加载+分组折叠+增强搜索）

struct JobLogView: View {
    let owner: String
    let repo: String
    let job: WorkflowJob

    // MARK: - 状态变量
    @State private var logs: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSteps: Bool = true
    @State private var selectedStepIndex: Int? = nil
    @State private var parsedExitCode: Int?
    @State private var isAutoRefreshing: Bool = false
    @State private var autoScrollToBottom: Bool = true
    @State private var showShareSheet: Bool = false
    @State private var exportedFileURL: URL?
    @State private var isExporting: Bool = false

    // MARK: - 性能优化相关状态
    @State private var allLogLines: [LogLine] = []      // 所有解析后的日志行
    @State private var visibleLineCount: Int = 1000       // 当前可见行数（增量加载）
    @State private var isLoadingMore: Bool = false         // 是否正在加载更多
    private let batchSize: Int = 1000                       // 每次加载的行数

    // MARK: - 分组折叠相关状态
    @State private var groups: [LogGroup] = []             // 所有分组
    @State private var collapsedGroupIds: Set<UUID> = []   // 已折叠的分组ID集合

    // MARK: - 搜索相关状态
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var searchMatches: [SearchMatch] = []    // 所有搜索匹配结果
    @State private var currentMatchIndex: Int = 0           // 当前匹配索引
    @State private var isCaseSensitive: Bool = false        // 区分大小写
    @State private var isRegexMode: Bool = false            // 正则模式
    @State private var isWholeWord: Bool = false            // 全词匹配
    @State private var showSearchOptions: Bool = false      // 显示搜索选项

    // MARK: - 滚动代理
    @State private var scrollProxy: ScrollViewProxy?

    // 自动刷新定时器
    private let autoRefreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // MARK: - 计算属性：当前可见的日志行（考虑分组折叠）
    private var visibleLogLines: [LogLine] {
        var result: [LogLine] = []
        var currentGroupId: UUID? = nil

        for (index, line) in allLogLines.enumerated() {
            // 增量加载：只显示前 visibleLineCount 行
            if result.count >= visibleLineCount {
                break
            }

            // 处理分组折叠
            if line.isGroupHeader {
                if let group = groups.first(where: { $0.startLine == line.lineNumber }) {
                    currentGroupId = group.id
                    if collapsedGroupIds.contains(group.id) {
                        // 分组已折叠，只显示分组标题行
                        result.append(line)
                        continue
                    }
                }
            }

            // 如果当前在已折叠的分组内，跳过
            if let groupId = currentGroupId,
               collapsedGroupIds.contains(groupId),
               !line.isGroupHeader {
                // 检查是否是分组结束行
                if line.type == .groupEnd {
                    currentGroupId = nil
                }
                continue
            }

            // 分组结束行
            if line.type == .groupEnd {
                currentGroupId = nil
            }

            result.append(line)
        }

        return result
    }

    // MARK: - 计算属性：是否还有更多行可加载
    private var hasMoreLines: Bool {
        visibleLineCount < allLogLines.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // 作业信息头部
            jobInfoHeader

            // 增强搜索栏
            if showSearch {
                enhancedSearchBar
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
                    if showSearch {
                        showSearchOptions = false
                    }
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
            if logs.isEmpty {
                loadLogs()
            }
            if job.status == "in_progress" {
                isAutoRefreshing = true
            }
            if job.conclusion == "failure" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollToFailedStep()
                }
            }
        }
        .onReceive(autoRefreshTimer) { _ in
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

    // MARK: - 增强搜索栏

    private var enhancedSearchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索日志...", text: $searchText, onCommit: {
                    performSearch()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
                .autocapitalization(.none)
                .disableAutocorrection(true)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchMatches = []
                        currentMatchIndex = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }

                Button(action: {
                    withAnimation {
                        showSearchOptions.toggle()
                    }
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(showSearchOptions ? .blue : .gray)
                }
            }

            // 搜索选项
            if showSearchOptions {
                HStack(spacing: 12) {
                    Toggle("区分大小写", isOn: $isCaseSensitive)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.caption2)
                    Toggle("正则", isOn: $isRegexMode)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.caption2)
                    Toggle("全词匹配", isOn: $isWholeWord)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.caption2)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .onChange(of: isCaseSensitive) { _ in performSearch() }
                .onChange(of: isRegexMode) { _ in performSearch() }
                .onChange(of: isWholeWord) { _ in performSearch() }
            }

            // 搜索结果导航
            if !searchMatches.isEmpty {
                HStack(spacing: 12) {
                    Text("找到 \(searchMatches.count) 处匹配")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        goToPreviousMatch()
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .disabled(currentMatchIndex <= 0)

                    Text("\(currentMatchIndex + 1)/\(searchMatches.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 50)

                    Button(action: {
                        goToNextMatch()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .disabled(currentMatchIndex >= searchMatches.count - 1)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .onChange(of: searchText) { _ in
            performSearch()
        }
    }

    // MARK: - 复选框样式
    struct CheckboxToggleStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            Button(action: {
                configuration.isOn.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                        .foregroundColor(configuration.isOn ? .blue : .gray)
                    configuration.label
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
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
            // 显示总行数和已加载行数
            Text("\(visibleLineCount)/\(allLogLines.count) 行")
                .font(.caption2)
                .foregroundColor(.secondary)
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

                    // 日志文本视图（虚拟滚动+增量加载）
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(visibleLogLines.enumerated()), id: \.element.id) { index, line in
                                    LogLineRow(
                                        line: line,
                                        isHighlighted: isLineHighlighted(lineNumber: line.lineNumber),
                                        isCurrentMatch: isCurrentMatch(lineNumber: line.lineNumber),
                                        searchText: searchText,
                                        isRegex: isRegexMode,
                                        isCaseSensitive: isCaseSensitive,
                                        isWholeWord: isWholeWord,
                                        onGroupTap: {
                                            toggleGroup(line: line)
                                        }
                                    )
                                    .id(line.lineNumber)
                                    .onAppear {
                                        // 滚动到底部附近时加载更多
                                        if index >= visibleLogLines.count - 50 && hasMoreLines && !isLoadingMore {
                                            loadMoreLines()
                                        }
                                    }
                                }

                                // 加载更多指示器
                                if hasMoreLines {
                                    HStack {
                                        Spacer()
                                        if isLoadingMore {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Button(action: {
                                                loadMoreLines()
                                            }) {
                                                Text("加载更多（还有 \(allLogLines.count - visibleLineCount) 行）")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .id("loadMore")
                                }

                                // 底部锚点
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(.vertical, 4)
                        }
                        .onAppear {
                            scrollProxy = proxy
                            if autoScrollToBottom {
                                DispatchQueue.main.async {
                                    withAnimation {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: logs) { _ in
                            if autoScrollToBottom {
                                DispatchQueue.main.async {
                                    withAnimation {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                }
            }
        }
    }

    // MARK: - 日志行视图

    struct LogLineRow: View {
        let line: LogLine
        let isHighlighted: Bool
        let isCurrentMatch: Bool
        let searchText: String
        let isRegex: Bool
        let isCaseSensitive: Bool
        let isWholeWord: Bool
        let onGroupTap: () -> Void

        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                // 行号
                Text("\(line.lineNumber)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, 6)

                // 分组折叠图标
                if line.isGroupHeader {
                    Button(action: onGroupTap) {
                        Image(systemName: line.type == .groupStart ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                            .frame(width: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4)
                } else {
                    Color.clear
                        .frame(width: 16)
                }

                // 日志内容（带搜索高亮）
                if !searchText.isEmpty && isHighlighted {
                    highlightedText(line.content)
                } else {
                    Text(line.content)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(colorForLineType(line.type))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 0.5)
            .background(
                isCurrentMatch ? Color.yellow.opacity(0.3) :
                isHighlighted ? Color.yellow.opacity(0.1) :
                line.type == .error ? Color.red.opacity(0.1) :
                line.lineNumber % 2 == 0 ? Color(.systemBackground) :
                Color(.systemGray6).opacity(0.3)
            )
        }

        // 文本片段模型（用于高亮渲染）
        struct TextSegment: Identifiable {
            let id = UUID()
            let text: String
            let isHighlighted: Bool
        }

        // 高亮搜索文本
        @ViewBuilder
        private func highlightedText(_ text: String) -> some View {
            if isRegex {
                regexHighlightedText(text)
            } else {
                normalHighlightedText(text)
            }
        }

        private func normalHighlightedText(_ text: String) -> some View {
            let options: String.CompareOptions = isCaseSensitive ? [] : .caseInsensitive
            var segments: [TextSegment] = []
            var currentIndex = text.startIndex

            while let range = text.range(of: searchText, options: options, range: currentIndex..<text.endIndex) {
                // 添加匹配前的文本
                if currentIndex < range.lowerBound {
                    segments.append(TextSegment(text: String(text[currentIndex..<range.lowerBound]), isHighlighted: false))
                }

                // 全词匹配检查
                let shouldHighlight = !isWholeWord || isWholeWordMatch(text: text, range: range)
                segments.append(TextSegment(text: String(text[range]), isHighlighted: shouldHighlight))

                currentIndex = range.upperBound
            }

            // 添加剩余文本
            if currentIndex < text.endIndex {
                segments.append(TextSegment(text: String(text[currentIndex..<text.endIndex]), isHighlighted: false))
            }

            // 使用Group和ForEach渲染片段
            return Group {
                ForEach(segments) { segment in
                    Text(segment.text)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(segment.isHighlighted ? .black : colorForLineType(line.type))
                        .background(segment.isHighlighted ? Color.yellow : Color.clear)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        // 计算正则匹配的文本片段
        private func calculateRegexSegments(_ text: String) -> (segments: [TextSegment], error: Error?) {
            var segments: [TextSegment] = []
            var currentIndex = text.startIndex

            do {
                let options: NSRegularExpression.Options = isCaseSensitive ? [] : .caseInsensitive
                let regex = try NSRegularExpression(pattern: searchText, options: options)
                let nsRange = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: nsRange)

                for match in matches {
                    if let range = Range(match.range, in: text) {
                        if currentIndex < range.lowerBound {
                            segments.append(TextSegment(text: String(text[currentIndex..<range.lowerBound]), isHighlighted: false))
                        }
                        segments.append(TextSegment(text: String(text[range]), isHighlighted: true))
                        currentIndex = range.upperBound
                    }
                }
            } catch {
                return (segments, error)
            }

            if currentIndex < text.endIndex {
                segments.append(TextSegment(text: String(text[currentIndex..<text.endIndex]), isHighlighted: false))
            }

            return (segments, nil)
        }

        @ViewBuilder
        private func regexHighlightedText(_ text: String) -> some View {
            let result = calculateRegexSegments(text)

            if result.error != nil {
                // 正则无效，显示普通文本
                Text(text)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(colorForLineType(line.type))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // 使用Group和ForEach渲染片段
                Group {
                    ForEach(result.segments) { segment in
                        Text(segment.text)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(segment.isHighlighted ? .black : colorForLineType(line.type))
                            .background(segment.isHighlighted ? Color.yellow : Color.clear)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        // 检查是否是全词匹配
        private func isWholeWordMatch(text: String, range: Range<String.Index>) -> Bool {
            let beforeChar = range.lowerBound > text.startIndex ? text[text.index(before: range.lowerBound)] : " "
            let afterChar = range.upperBound < text.endIndex ? text[range.upperBound] : " "

            let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

            let beforeIsWord = beforeChar.unicodeScalars.allSatisfy { wordChars.contains($0) }
            let afterIsWord = afterChar.unicodeScalars.allSatisfy { wordChars.contains($0) }

            return !beforeIsWord && !afterIsWord
        }

        private func colorForLineType(_ type: LogLineType) -> Color {
            switch type {
            case .error: return .red
            case .warning: return .orange
            case .success: return .green
            case .groupStart: return .blue
            case .groupEnd: return .purple
            case .normal: return .primary
            }
        }
    }

    // MARK: - 搜索相关方法

    private func performSearch() {
        guard !searchText.isEmpty else {
            searchMatches = []
            currentMatchIndex = 0
            return
        }

        searchMatches = []
        let visibleLines = visibleLogLines

        for (index, line) in visibleLines.enumerated() {
            if isRegexMode {
                do {
                    let options: NSRegularExpression.Options = isCaseSensitive ? [] : .caseInsensitive
                    let regex = try NSRegularExpression(pattern: searchText, options: options)
                    let nsRange = NSRange(line.content.startIndex..., in: line.content)
                    let matches = regex.matches(in: line.content, options: [], range: nsRange)
                    for match in matches {
                        if let range = Range(match.range, in: line.content) {
                            searchMatches.append(SearchMatch(lineIndex: index, lineNumber: line.lineNumber, range: range))
                        }
                    }
                } catch {
                    // 正则无效，跳过
                }
            } else {
                let options: String.CompareOptions = isCaseSensitive ? [] : .caseInsensitive
                var currentIndex = line.content.startIndex
                while let range = line.content.range(of: searchText, options: options, range: currentIndex..<line.content.endIndex) {
                    if isWholeWord {
                        // 全词匹配检查
                        let beforeChar = range.lowerBound > line.content.startIndex ? line.content[line.content.index(before: range.lowerBound)] : " "
                        let afterChar = range.upperBound < line.content.endIndex ? line.content[range.upperBound] : " "
                        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
                        let beforeIsWord = beforeChar.unicodeScalars.allSatisfy { wordChars.contains($0) }
                        let afterIsWord = afterChar.unicodeScalars.allSatisfy { wordChars.contains($0) }
                        if !beforeIsWord && !afterIsWord {
                            searchMatches.append(SearchMatch(lineIndex: index, lineNumber: line.lineNumber, range: range))
                        }
                    } else {
                        searchMatches.append(SearchMatch(lineIndex: index, lineNumber: line.lineNumber, range: range))
                    }
                    currentIndex = range.upperBound
                }
            }
        }

        currentMatchIndex = 0
        if !searchMatches.isEmpty {
            scrollToMatch(at: 0)
        }
    }

    private func goToPreviousMatch() {
        guard currentMatchIndex > 0 else { return }
        currentMatchIndex -= 1
        scrollToMatch(at: currentMatchIndex)
    }

    private func goToNextMatch() {
        guard currentMatchIndex < searchMatches.count - 1 else { return }
        currentMatchIndex += 1
        scrollToMatch(at: currentMatchIndex)
    }

    private func scrollToMatch(at index: Int) {
        guard index < searchMatches.count else { return }
        let match = searchMatches[index]
        DispatchQueue.main.async {
            withAnimation {
                scrollProxy?.scrollTo(match.lineNumber, anchor: .center)
            }
        }
    }

    private func isLineHighlighted(lineNumber: Int) -> Bool {
        searchMatches.contains { $0.lineNumber == lineNumber }
    }

    private func isCurrentMatch(lineNumber: Int) -> Bool {
        guard currentMatchIndex < searchMatches.count else { return false }
        return searchMatches[currentMatchIndex].lineNumber == lineNumber
    }

    // MARK: - 分组折叠相关方法

    private func toggleGroup(line: LogLine) {
        guard line.isGroupHeader else { return }
        guard let group = groups.first(where: { $0.startLine == line.lineNumber }) else { return }

        if collapsedGroupIds.contains(group.id) {
            collapsedGroupIds.remove(group.id)
        } else {
            collapsedGroupIds.insert(group.id)
        }
    }

    // MARK: - 增量加载方法

    private func loadMoreLines() {
        guard hasMoreLines && !isLoadingMore else { return }
        isLoadingMore = true

        // 模拟异步加载（实际是同步的，但为了UI体验加一点延迟）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            visibleLineCount = min(visibleLineCount + batchSize, allLogLines.count)
            isLoadingMore = false
            // 重新执行搜索（因为可见行变了）
            if !searchText.isEmpty {
                performSearch()
            }
        }
    }

    // MARK: - 日志解析方法

    private func parseLogLines(from logs: String) -> ([LogLine], [LogGroup]) {
        let lines = logs.components(separatedBy: .newlines)
        var logLines: [LogLine] = []
        var groups: [LogGroup] = []
        var currentGroup: LogGroup?

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let type = determineLineType(line)
            var isGroupHeader = false
            var groupName: String? = nil

            // 处理分组开始
            if type == .groupStart {
                isGroupHeader = true
                groupName = extractGroupName(from: line)
                let group = LogGroup(name: groupName ?? "分组", startLine: lineNumber, endLine: lineNumber, isCollapsed: false)
                groups.append(group)
                currentGroup = group
            }

            // 处理分组结束
            if type == .groupEnd {
                isGroupHeader = true
                if var group = currentGroup {
                    group.endLine = lineNumber
                    // 更新groups数组中的对应分组
                    if let groupIndex = groups.firstIndex(where: { $0.id == group.id }) {
                        groups[groupIndex] = group
                    }
                }
                currentGroup = nil
            }

            let logLine = LogLine(
                lineNumber: lineNumber,
                content: line,
                type: type,
                groupId: currentGroup?.id,
                isGroupHeader: isGroupHeader,
                groupName: groupName
            )
            logLines.append(logLine)
        }

        return (logLines, groups)
    }

    private func determineLineType(_ line: String) -> LogLineType {
        if line.hasPrefix("##[group]") || line.hasPrefix("::group::") {
            return .groupStart
        }
        if line.hasPrefix("##[endgroup]") || line.hasPrefix("::endgroup::") {
            return .groupEnd
        }
        let lowercased = line.lowercased()
        if lowercased.contains("error:") || lowercased.contains("fatal error") || lowercased.contains("::error::") || lowercased.contains("build failed") || lowercased.contains("编译失败") {
            return .error
        }
        if lowercased.contains("warning:") || lowercased.contains("::warning::") || lowercased.contains("警告") {
            return .warning
        }
        if lowercased.contains("success") || lowercased.contains("成功") || lowercased.contains("✅") {
            return .success
        }
        return .normal
    }

    private func extractGroupName(from line: String) -> String {
        if line.hasPrefix("##[group]") {
            return String(line.dropFirst("##[group]".count)).trimmingCharacters(in: .whitespaces)
        }
        if line.hasPrefix("::group::") {
            return String(line.dropFirst("::group::".count)).trimmingCharacters(in: .whitespaces)
        }
        return "分组"
    }

    // MARK: - 滚动到指定步骤

    private func scrollToStep(_ index: Int) {
        guard let steps = job.steps, index < steps.count else { return }
        let stepName = steps[index].name

        // 在日志中查找步骤名称的位置
        for line in allLogLines {
            if line.content.contains(stepName) {
                DispatchQueue.main.async {
                    withAnimation {
                        scrollProxy?.scrollTo(line.lineNumber, anchor: .top)
                    }
                }
                return
            }
        }
    }

    // MARK: - 滚动到失败步骤

    private func scrollToFailedStep() {
        guard let steps = job.steps else { return }

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
                    // 解析日志行和分组
                    let parsed = parseLogLines(from: logs)
                    self.allLogLines = parsed.0
                    self.groups = parsed.1
                    // 重置增量加载状态
                    self.visibleLineCount = min(1000, self.allLogLines.count)
                    self.collapsedGroupIds.removeAll()
                    // 从日志中解析退出码
                    self.parsedExitCode = Self.parseExitCode(from: logs)
                    // 重新执行搜索
                    if !searchText.isEmpty {
                        performSearch()
                    }
                case .failure(let error):
                    self.errorMessage = "加载日志失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 从日志中解析退出码

    private static func parseExitCode(from logs: String) -> Int? {
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let safeJobName = job.name.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeJobName)_\(timestamp).log"

        let fileManager = FileManager.default
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)

        do {
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
