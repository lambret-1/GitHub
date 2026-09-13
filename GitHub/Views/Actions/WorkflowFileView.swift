import SwiftUI

// MARK: - 工作流文件编辑器（支持查看和编辑YAML文件）

struct WorkflowFileView: View {
    let owner: String
    let repo: String
    let workflow: Workflow

    // 文件内容相关状态
    @State private var fileContent: String = ""
    @State private var originalContent: String = ""  // 原始内容，用于对比是否有修改
    @State private var fileSha: String = ""  // 文件的SHA，用于更新文件
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showCopySuccess: Bool = false

    // 编辑模式相关状态
    @State private var isEditing: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var commitMessage: String = ""
    @State private var showSaveSuccess: Bool = false
    @State private var showSaveError: String? = nil

    // 搜索相关状态
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var searchMatches: [Int] = []  // 匹配的行号
    @State private var currentMatchIndex: Int = 0

    // 滚动代理
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // 文件信息头部
            fileInfoHeader

            // 搜索栏
            if showSearch {
                searchBar
            }

            // 编辑模式提示栏
            if isEditing {
                editingBanner
            }

            // 内容区域
            contentSection
        }
        .navigationTitle(workflow.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            HStack(spacing: 16) {
                // 搜索按钮
                Button(action: {
                    showSearch.toggle()
                }) {
                    Image(systemName: "magnifyingglass")
                }

                // 编辑/完成按钮
                Button(action: {
                    if isEditing {
                        // 检查是否有修改
                        if fileContent != originalContent {
                            showSaveAlert = true
                        } else {
                            isEditing = false
                        }
                    } else {
                        isEditing = true
                    }
                }) {
                    Text(isEditing ? "完成" : "编辑")
                        .fontWeight(.medium)
                }

                // 复制按钮（仅查看模式显示）
                if !isEditing {
                    Button(action: {
                        copyContent()
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }

                // 刷新按钮
                Button(action: {
                    loadFileContent()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        )
        .onAppear {
            loadFileContent()
        }
        .alert("保存修改", isPresented: $showSaveAlert) {
            TextField("提交信息", text: $commitMessage)
            Button("保存", action: saveFile)
            Button("取消", role: .cancel) {
                isEditing = false
                fileContent = originalContent  // 恢复原始内容
            }
        } message: {
            Text("请输入提交信息，保存后将直接提交到仓库。")
        }
        .overlay(
            // 提示信息
            Group {
                if showCopySuccess {
                    toastView(message: "已复制到剪贴板", icon: "checkmark.circle.fill", color: .green)
                }
                if showSaveSuccess {
                    toastView(message: "保存成功", icon: "checkmark.circle.fill", color: .green)
                }
                if let error = showSaveError {
                    toastView(message: error, icon: "xmark.circle.fill", color: .red)
                }
            }
        )
    }

    // MARK: - Toast提示视图

    private func toastView(message: String, icon: String, color: Color) -> some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(message)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)  // 水平内边距16pt，控制左右留白间距
            .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
            .background(Color(.systemGray6))
            .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度
            .padding(.bottom, 40)  // 底部内边距40pt，控制下方留白间距
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - 文件信息头部

    private var fileInfoHeader: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("状态: \(workflow.state == "active" ? "启用" : "禁用")")
                    .font(.caption2)
                    .foregroundColor(workflow.state == "active" ? .green : .gray)
            }
            Spacer()
            // 显示是否有未保存的修改
            if isEditing && fileContent != originalContent {
                Text("未保存")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)  // 水平内边距6pt，控制左右留白间距
                    .padding(.vertical, 2)  // 垂直内边距2pt，控制上下留白间距
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)  // 圆角半径4pt，控制视图边角圆润程度
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
        .background(Color(.systemGray6))
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索...", text: $searchText, onCommit: {
                performSearch()
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(size: 14))  // 字体大小14pt，控制文字显示尺寸
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

                // 上一个/下一个匹配
                HStack(spacing: 4) {
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
                        .frame(minWidth: 40)

                    Button(action: {
                        goToNextMatch()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .disabled(currentMatchIndex >= searchMatches.count - 1)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
        .background(Color(.systemGray6))
        .onChange(of: searchText) { _ in
            performSearch()
        }
    }

    // MARK: - 编辑模式提示栏

    private var editingBanner: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundColor(.blue)
            Text("编辑模式 - 修改后点击完成保存")
                .font(.caption)
                .foregroundColor(.blue)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)  // 垂直内边距6pt，控制上下留白间距
        .background(Color.blue.opacity(0.1))
    }

    // MARK: - 内容区域

    private var contentSection: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载工作流文件中...")
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
                        loadFileContent()
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }
                .padding()
            } else if fileContent.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("文件内容为空")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                if isEditing {
                    // 编辑模式：使用TextEditor
                    editingContent
                } else {
                    // 查看模式：使用带语法高亮的ScrollView
                    viewingContent
                }
            }
        }
    }

    // MARK: - 编辑模式内容

    private var editingContent: some View {
        TextEditor(text: $fileContent)
            .font(.system(size: 12, design: .monospaced))  // 字体大小12pt，控制文字显示尺寸
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .padding(.horizontal, 8)  // 水平内边距8pt，控制左右留白间距
            .padding(.vertical, 4)  // 垂直内边距4pt，控制上下留白间距
            .background(Color(.systemBackground))
    }

    // MARK: - 查看模式内容

    private var viewingContent: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(fileContent.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 0) {
                            // 行号
                            Text("\(index + 1)")
                                .font(.system(size: 10, design: .monospaced))  // 字体大小10pt，控制文字显示尺寸
                                .foregroundColor(.gray)
                                .frame(width: 40, alignment: .trailing)
                                .padding(.trailing, 8)
                            // 代码内容（带搜索高亮）
                            if !searchText.isEmpty && searchMatches.contains(index) {
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))  // 字体大小10pt，控制文字显示尺寸
                                    .foregroundColor(colorForLine(line))
                                    .background(Color.yellow.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))  // 字体大小10pt，控制文字显示尺寸
                                    .foregroundColor(colorForLine(line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 4)  // 水平内边距4pt，控制左右留白间距
                        .padding(.vertical, 1)  // 垂直内边距1pt，控制上下留白间距
                        .background(
                            !searchText.isEmpty && searchMatches.contains(index) && currentMatchIndex < searchMatches.count && searchMatches[currentMatchIndex] == index ?
                            Color.yellow.opacity(0.2) :
                            (index % 2 == 0 ? Color(.systemBackground) : Color(.systemGray6).opacity(0.3))
                        )
                        .id(index)
                    }
                }
                .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - YAML语法高亮

    private func colorForLine(_ line: String) -> Color {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // 注释
        if trimmed.hasPrefix("#") {
            return .gray
        }
        // 键值对（key: value）
        if trimmed.contains(":") && !trimmed.hasPrefix("-") {
            return .blue
        }
        // 列表项
        if trimmed.hasPrefix("-") {
            return .green
        }
        // 字符串值
        if trimmed.hasPrefix("\"") || trimmed.hasPrefix("'") {
            return .orange
        }
        return .primary
    }

    // MARK: - 搜索相关方法

    private func performSearch() {
        guard !searchText.isEmpty else {
            searchMatches = []
            currentMatchIndex = 0
            return
        }

        let lines = fileContent.components(separatedBy: .newlines)
        searchMatches = []

        for (index, line) in lines.enumerated() {
            if line.localizedCaseInsensitiveContains(searchText) {
                searchMatches.append(index)
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
        let lineIndex = searchMatches[index]
        DispatchQueue.main.async {
            withAnimation {
                scrollProxy?.scrollTo(lineIndex, anchor: .center)
            }
        }
    }

    // MARK: - 数据加载

    private func loadFileContent() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getFileContent(owner: owner, repo: repo, path: workflow.path) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fileContent):
                    let content = fileContent.decodedContent
                    if !content.isEmpty {
                        self.fileContent = content
                        self.originalContent = content
                        self.fileSha = fileContent.sha
                    } else {
                        self.errorMessage = "无法解码文件内容"
                    }
                case .failure(let error):
                    self.errorMessage = "加载失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 保存文件

    private func saveFile() {
        guard !commitMessage.isEmpty else {
            showSaveError = "请输入提交信息"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSaveError = nil
            }
            return
        }

        isSaving = true
        showSaveAlert = false

        GitHubAPI.shared.updateFile(
            owner: owner,
            repo: repo,
            path: workflow.path,
            content: fileContent,
            sha: fileSha,
            message: commitMessage
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    originalContent = fileContent
                    isEditing = false
                    commitMessage = ""
                    showSaveSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSaveSuccess = false
                    }
                case .failure(let error):
                    showSaveError = "保存失败: \(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSaveError = nil
                    }
                }
            }
        }
    }

    // MARK: - 复制内容

    private func copyContent() {
        UIPasteboard.general.string = fileContent
        withAnimation {
            showCopySuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopySuccess = false
            }
        }
    }
}
