import SwiftUI

// MARK: - 通用文件编辑器视图
// 功能：查看文件内容、编辑文件、搜索内容、保存提交到仓库

struct FileEditorView: View {
    let owner: String
    let repo: String
    let filePath: String
    let branch: String

    // 文件内容相关状态
    @State private var fileContent: String = ""
    @State private var originalContent: String = ""
    @State private var fileSha: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showCopySuccess: Bool = false

    // 编辑模式相关状态
    @State private var isEditing: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var commitMessage: String = ""
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    @State private var showSaveSuccess: Bool = false

    // 搜索相关状态
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    // 环境对象
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            if showSearch {
                searchBar
            }

            // 文件内容区域
            fileContentSection
        }
        .navigationTitle((filePath as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 搜索按钮
                    Button(action: {
                        showSearch.toggle()
                        if !showSearch {
                            searchText = ""
                            currentMatchIndex = 0
                            totalMatches = 0
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                    }

                    // 复制按钮
                    Button(action: {
                        UIPasteboard.general.string = fileContent
                        showCopySuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopySuccess = false
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                    }

                    // 编辑/完成按钮
                    Button(action: {
                        if isEditing {
                            // 完成编辑，检查是否有修改
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
                }
            }
        }
        .alert("保存修改", isPresented: $showSaveAlert) {
            TextField("提交信息", text: $commitMessage)
            Button("保存") {
                saveFile()
            }
            Button("取消", role: .cancel) {
                isEditing = false
                fileContent = originalContent
            }
        } message: {
            Text("输入提交信息，将修改保存到仓库")
        }
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("确定") {
                isEditing = false
            }
        } message: {
            Text("文件已成功提交到仓库")
        }
        .alert("保存失败", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("确定") {}
        } message: {
            Text(saveErrorMessage ?? "未知错误")
        }
        .overlay {
            if showCopySuccess {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("已复制到剪贴板")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(24)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(12)
                .shadow(radius: 8)
            }

            if isSaving {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在保存...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
        }
        .onAppear {
            loadFileContent()
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索内容", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _ in
                    calculateMatches()
                }
            if !searchText.isEmpty {
                Text("\(currentMatchIndex + 1)/\(totalMatches)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(action: {
                    findPrevious()
                }) {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.blue)
                }
                Button(action: {
                    findNext()
                }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - 文件内容区域

    private var fileContentSection: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载文件中...")
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
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else if isEditing {
                // 编辑模式：使用TextEditor
                TextEditor(text: $fileContent)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .background(Color(.systemBackground))
            } else {
                // 查看模式：使用ScrollView+Text
                ScrollView {
                    if totalMatches > 0 && !searchText.isEmpty {
                        // 有搜索结果时，显示高亮内容
                        highlightedContent
                    } else {
                        Text(fileContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                }
            }
        }
    }

    // MARK: - 高亮搜索内容

    private var highlightedContent: some View {
        let lines = fileContent.components(separatedBy: .newlines)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 8) {
                    // 行号
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    // 内容（高亮匹配项）
                    highlightText(in: line)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 4)
                .background(isLineMatch(line) ? Color.yellow.opacity(0.2) : Color.clear)
            }
        }
        .padding(8)
    }

    private func highlightText(in line: String) -> Text {
        guard !searchText.isEmpty else {
            return Text(line)
        }
        var result = Text("")
        var remaining = line
        while let range = remaining.range(of: searchText, options: .caseInsensitive) {
            let before = String(remaining[..<range.lowerBound])
            let match = String(remaining[range])
            result = result + Text(before) + Text(match).background(Color.yellow).foregroundColor(.black)
            remaining = String(remaining[range.upperBound...])
        }
        result = result + Text(remaining)
        return result
    }

    private func isLineMatch(_ line: String) -> Bool {
        return line.range(of: searchText, options: .caseInsensitive) != nil
    }

    // MARK: - 搜索功能

    private func calculateMatches() {
        guard !searchText.isEmpty else {
            totalMatches = 0
            currentMatchIndex = 0
            return
        }
        let lines = fileContent.components(separatedBy: .newlines)
        totalMatches = lines.filter { isLineMatch($0) }.count
        currentMatchIndex = 0
    }

    private func findNext() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
    }

    private func findPrevious() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
    }

    // MARK: - 加载文件内容

    private func loadFileContent() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getFileContent(
            owner: owner,
            repo: repo,
            path: filePath,
            branch: branch
        ) { result in
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
                    self.errorMessage = "加载文件失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 保存文件

    private func saveFile() {
        guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            saveErrorMessage = "请输入提交信息"
            return
        }

        isSaving = true
        saveErrorMessage = nil

        GitHubAPI.shared.updateFile(
            owner: owner,
            repo: repo,
            path: filePath,
            content: fileContent,
            sha: fileSha,
            message: commitMessage,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    self.originalContent = self.fileContent
                    self.commitMessage = ""
                    self.showSaveSuccess = true
                    // 重新加载文件内容以获取新的sha
                    self.loadFileContent()
                case .failure(let error):
                    self.saveErrorMessage = "保存失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
