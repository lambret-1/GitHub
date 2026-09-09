import SwiftUI

struct CodeEditorView: View {
    let owner: String
    let repo: String
    let path: String
    let branch: String
    let fileName: String
    
    @State private var fileContent: FileContent?
    @State private var codeText: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var isEditing: Bool = false
    @State private var showCommitDialog: Bool = false
    @State private var commitMessage: String = ""
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false
    @State private var showLineNumbers: Bool = true
    @State private var fontSize: CGFloat = 10
    @State private var showSettings: Bool = false
    @State private var showRenameDialog: Bool = false
    @State private var newFileName: String = ""
    @State private var isRenaming: Bool = false
    @State private var showRenameSuccess: Bool = false
    @State private var renameErrorMessage: String?
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var showCopySuccess: Bool = false
    @State private var lastCommitInfo: Commit?

    // 查找相关状态
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    // 选中文字查找相关状态
    @State private var getSelectedTextTrigger: Int = 0
    @State private var showNoSelectionAlert: Bool = false
    @State private var waitingForSelectedText: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("加载文件中...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        loadFile()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else if let content = fileContent {
                if !content.isTextFile {
                    // 二进制文件提示
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("此文件为二进制文件，无法在线编辑")
                            .foregroundColor(.secondary)
                        if let downloadUrl = content.downloadUrl {
                            Button("下载文件") {
                                if let url = URL(string: downloadUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Spacer()
                } else {
                    // 代码编辑器
                    codeEditorArea
                }
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // 文件操作
                    Button(action: {
                        showRenameDialog = true
                        newFileName = fileName
                    }) {
                        Label("重命名文件", systemImage: "pencil")
                    }

                    Button(action: {
                        copyFilePath()
                    }) {
                        Label("复制文件路径", systemImage: "doc.on.doc")
                    }

                    Button(action: {
                        downloadFile()
                    }) {
                        Label("下载该文件", systemImage: "square.and.arrow.down")
                    }

                    Divider()

                    if fileContent?.isTextFile ?? false {
                        Button(action: {
                            showSearch.toggle()
                            if !showSearch {
                                searchText = ""
                                currentMatchIndex = 0
                                totalMatches = 0
                            }
                        }) {
                            Label(showSearch ? "关闭查找" : "查找", systemImage: "magnifyingglass")
                        }

                        Button(action: {
                            isEditing.toggle()
                        }) {
                            Label(isEditing ? "完成编辑" : "编辑文件", systemImage: isEditing ? "checkmark" : "pencil")
                        }

                        Button(action: {
                            UIPasteboard.general.string = codeText
                        }) {
                            Label("复制全部内容", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(action: {
                            showLineNumbers.toggle()
                        }) {
                            Label(showLineNumbers ? "隐藏行号" : "显示行号", systemImage: "number")
                        }

                        Button(action: {
                            fontSize = max(10, fontSize - 1)
                        }) {
                            Label("减小字号", systemImage: "textformat.size.smaller")
                        }

                        Button(action: {
                            fontSize = min(24, fontSize + 1)
                        }) {
                            Label("增大字号", systemImage: "textformat.size.larger")
                        }

                        Divider()
                    }

                    if let htmlUrl = fileContent?.htmlUrl {
                        Button(action: {
                            if let url = URL(string: htmlUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("在 GitHub 打开", systemImage: "safari")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isRenaming || isDownloading)
            }
        }
        .alert("提交修改", isPresented: $showCommitDialog) {
            TextField("提交信息（如：更新 xxx）", text: $commitMessage)
            Button("取消", role: .cancel) {}
            Button("提交") {
                commitChanges()
            }
        } message: {
            Text("将修改提交到 \(branch) 分支")
        }
        .alert("提交成功", isPresented: $showSaveSuccess) {
            Button("确定") {
                isEditing = false
                loadFile()
            }
        } message: {
            Text("文件已成功提交到 GitHub 仓库")
        }
        .alert("重命名文件", isPresented: $showRenameDialog) {
            TextField("新文件名", text: $newFileName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                renameFile()
            }
            .disabled(newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("当前文件名: \(fileName)\n请输入新的文件名")
        }
        .alert("重命名成功", isPresented: $showRenameSuccess) {
            Button("确定") {
                // 返回上一页
                NotificationCenter.default.post(name: NSNotification.Name("FileRenamed"), object: nil)
            }
        } message: {
            Text("文件已成功重命名")
        }
        .alert("重命名失败", isPresented: .constant(renameErrorMessage != nil)) {
            Button("确定") {
                renameErrorMessage = nil
            }
        } message: {
            Text(renameErrorMessage ?? "未知错误")
        }
        .alert("复制成功", isPresented: $showCopySuccess) {
            Button("确定") {}
        } message: {
            Text("文件 Raw 地址已复制到剪贴板")
        }
        .alert("未选中文字", isPresented: $showNoSelectionAlert) {
            Button("确定") {}
        } message: {
            Text("请先在代码中选中要查找的文字，然后再点击「查找选中文字」")
        }
        .overlay {
            if isDownloading {
                downloadProgressOverlay
            }
        }
        .onAppear {
            loadFile()
        }
    }

    // MARK: - 下载进度覆盖层

    private var downloadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .frame(width: 70, height: 70)
                    .background(Color(.systemGray6))
                    .cornerRadius(35)

                Text("正在下载文件")
                    .font(.headline)

                Text(fileName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 250)

                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 250)

                Text(String(format: "%.0f%%", downloadProgress * 100))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
    
    // MARK: - 文件信息栏

    private var fileInfoBar: some View {
        HStack(spacing: 12) {
            // 文件大小
            if let content = fileContent {
                Label(content.size.formattedFileSize, systemImage: "doc")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 最后编辑时间
            if let commit = lastCommitInfo {
                Label(commit.commit.committer.relativeDate, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Label("加载中...", systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    // MARK: - 代码编辑区域

    private var codeEditorArea: some View {
        VStack(spacing: 0) {
            // 文件信息栏
            fileInfoBar

            // 编辑模式提示条
            if isEditing {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                    Text("编辑模式")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                    if hasChanges {
                        Text("已修改")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                
                // 提交按钮
                HStack(spacing: 12) {
                    Button(action: {
                        codeText = originalContent
                        isEditing = false
                    }) {
                        Text("取消")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        commitMessage = "Update \(fileName)"
                        showCommitDialog = true
                    }) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("提交修改")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.black)
                    .cornerRadius(8)
                    .disabled(!hasChanges || isSaving)
                    .opacity((!hasChanges || isSaving) ? 0.5 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // 查找栏
            if showSearch {
                searchBar
            }

            // 代码显示/编辑区 - 使用高性能CodeTextView，基于原生UITextView
            CodeTextView(
                text: $codeText,
                isEditable: isEditing,
                showLineNumbers: showLineNumbers,
                fontSize: fontSize,
                onTextChange: { _ in },
                onSearchResult: { current, total in
                    currentMatchIndex = current - 1
                    totalMatches = total
                },
                onLookupSelectedText: { selectedText in
                    // 选中文字后点击编辑菜单中的"🔍查找"，直接查找选中的文字
                    searchText = selectedText
                    currentMatchIndex = 0
                    showSearch = true
                },
                searchText: searchText,
                currentMatchIndex: currentMatchIndex,
                isSearchActive: showSearch && !searchText.isEmpty,
                getSelectedTextTrigger: getSelectedTextTrigger,
                onSelectedText: { selectedText in
                    // 获取到选中文字后，自动填入查找框并显示查找栏
                    waitingForSelectedText = false
                    searchText = selectedText
                    currentMatchIndex = 0
                    showSearch = true
                }
            )
        }
    }

    // MARK: - 选中文字查找

    private func searchSelectedText() {
        // 设置等待标志
        waitingForSelectedText = true

        // 递增触发器，触发CodeTextView获取选中文字
        getSelectedTextTrigger += 1

        // 延迟200ms检查是否有选中文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if waitingForSelectedText {
                // 没有选中文字，显示提示
                waitingForSelectedText = false
                showNoSelectionAlert = true
            }
        }
    }

    // MARK: - 查找栏

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("查找代码...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { _ in
                        currentMatchIndex = 0
                    }

                // 查找结果显示
                if totalMatches > 0 {
                    Text("\(currentMatchIndex + 1)/\(totalMatches)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 50)
                } else if !searchText.isEmpty {
                    Text("无结果")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(minWidth: 50)
                }
            }

            HStack(spacing: 12) {
                // 关闭查找（左侧，左手操作）
                Button(action: {
                    showSearch = false
                    searchText = ""
                    currentMatchIndex = 0
                    totalMatches = 0
                }) {
                    Text("完成")
                        .foregroundColor(.blue)
                        .frame(height: 36)
                }

                Spacer()

                // 下一个（右侧，右手拇指操作）
                Button(action: {
                    if totalMatches > 0 {
                        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("下一个")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                    .foregroundColor(.white)
                    .frame(width: 90, height: 36)
                    .background(totalMatches > 0 ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(totalMatches == 0)

                // 上一个（右侧，右手拇指操作）
                Button(action: {
                    if totalMatches > 0 {
                        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("上一个")
                            .font(.subheadline)
                        Image(systemName: "chevron.up")
                    }
                    .foregroundColor(.white)
                    .frame(width: 90, height: 36)
                    .background(totalMatches > 0 ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(totalMatches == 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var hasChanges: Bool {
        return codeText != originalContent
    }
    
    private func loadFile() {
        isLoading = true
        errorMessage = nil
        lastCommitInfo = nil

        GitHubAPI.shared.getFileContent(owner: owner, repo: repo, path: path, branch: branch) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let file):
                    fileContent = file
                    codeText = file.decodedContent
                    originalContent = codeText

                    // 获取文件最后编辑时间
                    loadLastCommit()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadLastCommit() {
        GitHubAPI.shared.getFileLastCommit(owner: owner, repo: repo, path: path, branch: branch) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let commit):
                    lastCommitInfo = commit
                case .failure:
                    break
                }
            }
        }
    }
    
    private func commitChanges() {
        guard let sha = fileContent?.sha else { return }
        guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            commitMessage = "Update \(fileName)"
            return
        }

        isSaving = true

        GitHubAPI.shared.updateFile(
            owner: owner,
            repo: repo,
            path: path,
            content: codeText,
            sha: sha,
            message: commitMessage,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    showSaveSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 重命名文件

    private func renameFile() {
        let trimmedName = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            renameErrorMessage = "文件名不能为空"
            return
        }

        guard trimmedName != fileName else {
            renameErrorMessage = "新文件名与原文件名相同，请输入不同的文件名"
            return
        }

        isRenaming = true

        // 计算新路径
        let pathComponents = path.components(separatedBy: "/")
        var newPathComponents = pathComponents
        newPathComponents.removeLast()
        newPathComponents.append(trimmedName)
        let newPath = newPathComponents.joined(separator: "/")

        GitHubAPI.shared.renameFile(
            owner: owner,
            repo: repo,
            oldPath: path,
            newPath: newPath,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isRenaming = false
                switch result {
                case .success:
                    showRenameSuccess = true
                case .failure(let error):
                    renameErrorMessage = "重命名失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 复制文件Raw地址

    private func copyFilePath() {
        let rawUrl = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(path)"
        UIPasteboard.general.string = rawUrl
        showCopySuccess = true
    }

    // MARK: - 下载文件

    private func downloadFile() {
        guard let downloadUrl = fileContent?.downloadUrl else {
            renameErrorMessage = "该文件不支持下载"
            return
        }

        isDownloading = true
        downloadProgress = 0

        FileDownloadManager.shared.downloadAndShare(
            from: downloadUrl,
            fileName: fileName,
            progress: { progress in
                self.downloadProgress = progress
            }
        ) { result in
            DispatchQueue.main.async {
                self.isDownloading = false
                if case .failure(let error) = result {
                    self.renameErrorMessage = "下载失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct CodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        CodeEditorView(
            owner: "test",
            repo: "test",
            path: "README.md",
            branch: "main",
            fileName: "README.md"
        )
    }
}
