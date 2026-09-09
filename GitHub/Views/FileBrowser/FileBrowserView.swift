import SwiftUI

struct FileBrowserView: View {
    let repository: Repository
    @State private var files: [FileItem] = []
    @State private var currentPath: String = ""
    @State private var pathStack: [String] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var branches: [Branch] = []
    @State private var selectedBranch: String = ""
    @State private var showBranchPicker: Bool = false
    @State private var showCommits: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0
    @State private var selectedFiles: [URL] = []
    @State private var showUploadConfirm: Bool = false
    @State private var currentUploadIndex: Int = 0
    @State private var totalUploadCount: Int = 0
    @State private var currentUploadFileName: String = ""
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var downloadingFileName: String = ""
    @State private var showActionSheet: Bool = false
    @State private var selectedFile: FileItem?
    @State private var showUploadSuccess: Bool = false
    @State private var uploadErrorMessage: String?
    @State private var showCreateFolderDialog: Bool = false
    @State private var newFolderName: String = ""
    @State private var isCreatingFolder: Bool = false
    @State private var showCreateFolderSuccess: Bool = false
    @State private var createFolderErrorMessage: String?

    // 新建文件相关状态
    @State private var showCreateFileDialog: Bool = false
    @State private var newFileName: String = ""
    @State private var isCreatingFile: Bool = false
    @State private var showCreateFileSuccess: Bool = false
    @State private var createFileErrorMessage: String?

    // 删除文件相关状态
    @State private var isDeleteMode: Bool = false
    @State private var selectedFilesForDelete: Set<String> = []
    @State private var isDeleting: Bool = false
    @State private var showDeleteConfirm: Bool = false

    // 新创建文件路径，用于跳转到编辑状态
    @State private var newlyCreatedFilePath: String?
    @State private var navigateToEditor: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            pathNavigationBar
            fileListContent
            // 删除模式底部操作栏
            if isDeleteMode {
                deleteActionBar
            }
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        // 隐藏的NavigationLink，用于创建文件成功后跳转到编辑状态
        .background(
            NavigationLink(destination: Group {
                if let filePath = newlyCreatedFilePath {
                    CodeEditorView(
                        owner: repository.ownerName,
                        repo: repository.name,
                        path: filePath,
                        branch: selectedBranch,
                        fileName: (filePath as NSString).lastPathComponent
                    )
                }
            }, isActive: $navigateToEditor) {
                EmptyView()
            }
            .hidden()
        )
        .sheet(isPresented: $showBranchPicker) {
            BranchPickerView(branches: branches, selectedBranch: $selectedBranch) {
                loadFiles()
                showBranchPicker = false
            }
        }
        .sheet(isPresented: $showCommits) {
            CommitsView(owner: repository.ownerName, repo: repository.name)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(allowsMultipleSelection: true) { urls in
                selectedFiles = urls
                showUploadConfirm = true
            }
        }
        .sheet(isPresented: $showUploadConfirm) {
            uploadConfirmView
        }
        .alert("上传完成", isPresented: $showUploadSuccess) {
            Button("确定", role: .cancel) {
                loadFiles()
            }
        } message: {
            Text("文件已成功上传到仓库")
        }
        .alert("上传失败", isPresented: .constant(uploadErrorMessage != nil)) {
            Button("确定", role: .cancel) {
                uploadErrorMessage = nil
            }
        } message: {
            Text(uploadErrorMessage ?? "未知错误")
        }
        // 创建文件夹对话框（使用sheet替代alert，确保创建按钮正常显示）
        .sheet(isPresented: $showCreateFolderDialog) {
            CreateFolderView(currentPath: currentPath) { folderName in
                createFolder(folderName: folderName)
            } onCancel: {
                showCreateFolderDialog = false
            }
        }
        .alert("创建成功", isPresented: $showCreateFolderSuccess) {
            Button("确定") {
                loadFiles()
            }
        } message: {
            Text("文件夹已成功创建")
        }
        .alert("创建失败", isPresented: .constant(createFolderErrorMessage != nil)) {
            Button("确定", role: .cancel) {
                createFolderErrorMessage = nil
            }
        } message: {
            Text(createFolderErrorMessage ?? "未知错误")
        }
        // 新建文件对话框（使用sheet替代alert，确保创建按钮正常显示）
        .sheet(isPresented: $showCreateFileDialog) {
            CreateFileView(currentPath: currentPath) { fileName in
                createFile(fileName: fileName)
            } onCancel: {
                showCreateFileDialog = false
            }
        }
        .alert("创建成功", isPresented: $showCreateFileSuccess) {
            Button("确定") {
                loadFiles()
            }
        } message: {
            Text("文件已成功创建")
        }
        .alert("创建失败", isPresented: .constant(createFileErrorMessage != nil)) {
            Button("确定", role: .cancel) {
                createFileErrorMessage = nil
            }
        } message: {
            Text(createFileErrorMessage ?? "未知错误")
        }
        // 删除确认对话框
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteSelectedFiles()
            }
        } message: {
            Text("确定要删除选中的 \(selectedFilesForDelete.count) 个文件/文件夹吗？此操作不可撤销。")
        }
        .overlay {
            progressOverlay
        }
        .onAppear {
            if selectedBranch.isEmpty {
                selectedBranch = repository.defaultBranch
            }
            loadBranches()
            loadFiles()
        }
    }
    
    // MARK: - 文件列表内容

    @ViewBuilder
    private var fileListContent: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(error: error)
        } else if files.isEmpty {
            emptyView
        } else {
            fileListView
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("加载中...")
            Spacer()
        }
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                loadFiles()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("此目录为空")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var fileListView: some View {
        List {
            if !pathStack.isEmpty || !currentPath.isEmpty {
                Button(action: navigateUp) {
                    HStack {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("返回上一级")
                            .foregroundColor(.blue)
                    }
                }
            }

            ForEach(files.sorted(by: { $0.isDirectory && !$1.isDirectory })) { file in
                fileRowView(for: file)
            }
        }
        .listStyle(PlainListStyle())
        // 下拉刷新功能，识别区在列表顶部（上半屏）
        .refreshable {
            await loadFilesAsync()
        }
    }

    // 异步加载文件，用于下拉刷新
    private func loadFilesAsync() async {
        await withCheckedContinuation { continuation in
            loadFiles()
            // 延迟一点时间，让刷新动画更自然
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }

    // MARK: - 删除模式底部操作栏

    private var deleteActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // 已选择数量
                Text("已选择 \(selectedFilesForDelete.count) 项")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // 全选/取消全选
                Button(action: {
                    if selectedFilesForDelete.count == files.count {
                        selectedFilesForDelete.removeAll()
                    } else {
                        selectedFilesForDelete = Set(files.map { $0.path })
                    }
                }) {
                    Text(selectedFilesForDelete.count == files.count ? "取消全选" : "全选")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                // 删除按钮
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("删除")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedFilesForDelete.isEmpty ? Color.gray : Color.red)
                    .cornerRadius(8)
                }
                .disabled(selectedFilesForDelete.isEmpty || isDeleting)

                // 取消按钮
                Button(action: {
                    isDeleteMode = false
                    selectedFilesForDelete.removeAll()
                }) {
                    Text("取消")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - 工具栏内容

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            moreMenu
        }
    }

    private var moreMenu: some View {
        Menu {
            Button(action: {
                showDocumentPicker = true
            }) {
                Label("上传文件", systemImage: "square.and.arrow.up")
            }
            .disabled(isUploading || isDownloading || isDeleteMode)

            Button(action: {
                showCreateFileDialog = true
                newFileName = ""
            }) {
                Label("新建文件", systemImage: "doc.badge.plus")
            }
            .disabled(isCreatingFile || isDeleteMode)

            Button(action: {
                showCreateFolderDialog = true
                newFolderName = ""
            }) {
                Label("创建文件夹", systemImage: "folder.badge.plus")
            }
            .disabled(isCreatingFolder || isDeleteMode)

            Divider()

            Button(action: {
                isDeleteMode.toggle()
                selectedFilesForDelete.removeAll()
            }) {
                Label(isDeleteMode ? "取消删除" : "删除文件", systemImage: isDeleteMode ? "xmark.circle" : "trash")
            }

            Divider()

            Button(action: {
                showBranchPicker = true
            }) {
                Label("切换分支: \(selectedBranch)", systemImage: "arrow.triangle.branch")
            }
            .disabled(isDeleteMode)

            Button(action: {
                showCommits = true
            }) {
                Label("提交记录", systemImage: "clock.arrow.circlepath")
            }
            .disabled(isDeleteMode)

            Button(action: {
                if let url = URL(string: repository.htmlUrl) {
                    UIApplication.shared.open(url)
                }
            }) {
                Label("在 GitHub 打开", systemImage: "safari")
            }
            .disabled(isDeleteMode)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - 确认上传弹窗

    private var uploadConfirmView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部信息
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    Text("确认上传文件")
                        .font(.headline)
                    Text("已选择 \(selectedFiles.count) 个文件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("上传到: \(currentPath.isEmpty ? "根目录" : currentPath)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 16)
                .padding(.horizontal)

                Divider()

                // 文件列表
                List {
                    ForEach(Array(selectedFiles.enumerated()), id: \.element) { index, fileURL in
                        HStack(spacing: 12) {
                            // 文件图标
                            Image(systemName: fileIcon(for: fileURL))
                                .font(.system(size: 24))
                                .foregroundColor(fileIconColor(for: fileURL))
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            // 文件信息
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fileURL.lastPathComponent)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(fileSizeString(for: fileURL))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            // 序号
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(width: 24, height: 24)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: removeSelectedFile)
                }
                .listStyle(PlainListStyle())

                Divider()

                // 底部按钮
                VStack(spacing: 12) {
                    Button(action: {
                        startUpload()
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("开始上传 (\(selectedFiles.count) 个文件)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(selectedFiles.isEmpty)

                    Button(action: {
                        showUploadConfirm = false
                        selectedFiles = []
                    }) {
                        Text("取消")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - 文件图标

    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "svg", "webp", "heic":
            return "photo"
        case "mp4", "mov", "avi", "mkv", "webm":
            return "film"
        case "mp3", "wav", "flac", "aac", "ogg":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx", "csv":
            return "tablecells"
        case "ppt", "pptx":
            return "presentation"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "swift", "m", "h", "mm", "cpp", "c", "hpp", "java", "py", "js", "ts", "go", "rs", "kt":
            return "chevron.left.forwardslash.chevron.right"
        case "txt", "md", "markdown":
            return "text.alignleft"
        case "json", "xml", "yaml", "yml":
            return "curlybraces"
        case "html", "css":
            return "globe"
        case "ipa":
            return "app"
        default:
            return "doc"
        }
    }

    private func fileIconColor(for url: URL) -> Color {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "svg", "webp", "heic":
            return .purple
        case "mp4", "mov", "avi", "mkv", "webm":
            return .pink
        case "mp3", "wav", "flac", "aac", "ogg":
            return .red
        case "pdf":
            return .red
        case "doc", "docx":
            return .blue
        case "xls", "xlsx", "csv":
            return .green
        case "ppt", "pptx":
            return .orange
        case "zip", "rar", "7z", "tar", "gz":
            return .brown
        case "swift", "m", "h", "mm", "cpp", "c", "hpp", "java", "py", "js", "ts", "go", "rs", "kt":
            return .orange
        default:
            return .gray
        }
    }

    private func fileSizeString(for url: URL) -> String {
        guard let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = resources.fileSize else {
            return "未知大小"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    private func removeSelectedFile(at offsets: IndexSet) {
        selectedFiles.remove(atOffsets: offsets)
    }

    // MARK: - 进度覆盖层

    @ViewBuilder
    private var progressOverlay: some View {
        if isDownloading {
            downloadProgressView
        } else if isUploading {
            uploadProgressView
        }
    }

    private var downloadProgressView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)

                Text("正在下载: \(downloadingFileName)")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(String(format: "%.0f%%", downloadProgress * 100))
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(.systemGray6).opacity(0.9))
            .cornerRadius(16)
        }
    }

    private var uploadProgressView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // 图标
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .frame(width: 70, height: 70)
                    .background(Color(.systemGray6))
                    .cornerRadius(35)

                // 标题
                Text("正在上传文件")
                    .font(.headline)
                    .foregroundColor(.primary)

                // 当前文件名
                if !currentUploadFileName.isEmpty {
                    VStack(spacing: 4) {
                        Text(currentUploadFileName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 250)
                        Text("第 \(currentUploadIndex + 1) / \(totalUploadCount) 个文件")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // 进度条
                VStack(spacing: 8) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 250)

                    Text(String(format: "%.0f%%", uploadProgress * 100))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 提示
                Text("请勿关闭应用")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }

    // 路径导航栏
    private var pathNavigationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button(action: {
                    pathStack.removeAll()
                    currentPath = ""
                    loadFiles()
                }) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                
                if !currentPath.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    let components = currentPath.components(separatedBy: "/")
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        Button(action: {
                            let newPath = components.prefix(index + 1).joined(separator: "/")
                            currentPath = newPath
                            pathStack = Array(pathStack.prefix(index))
                            loadFiles()
                        }) {
                            Text(component)
                                .font(.caption)
                                .foregroundColor(index == components.count - 1 ? .primary : .blue)
                        }
                        if index < components.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }
    
    private func loadFiles() {
        isLoading = true
        errorMessage = nil
        
        GitHubAPI.shared.getDirectoryContents(
            owner: repository.ownerName,
            repo: repository.name,
            path: currentPath,
            branch: selectedBranch
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let files):
                    self.files = files
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadBranches() {
        GitHubAPI.shared.getBranches(owner: repository.ownerName, repo: repository.name) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let branches):
                    self.branches = branches
                case .failure:
                    break
                }
            }
        }
    }
    
    private func navigateToDirectory(_ path: String) {
        pathStack.append(currentPath)
        currentPath = path
        loadFiles()
    }
    
    private func navigateUp() {
        if let previousPath = pathStack.popLast() {
            currentPath = previousPath
        } else {
            currentPath = ""
        }
        loadFiles()
    }

    // MARK: - 文件行视图

    @ViewBuilder
    private func fileRowView(for file: FileItem) -> some View {
        // 删除模式：显示复选框，点击切换选择状态
        if isDeleteMode {
            Button(action: {
                toggleFileSelection(file)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: selectedFilesForDelete.contains(file.path) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedFilesForDelete.contains(file.path) ? .blue : .gray)
                        .font(.system(size: 20))
                    FileRow(file: file, owner: repository.ownerName, repo: repository.name, branch: selectedBranch)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } else if file.isDirectory {
            Button(action: {
                navigateToDirectory(file.path)
            }) {
                FileRow(file: file, owner: repository.ownerName, repo: repository.name, branch: selectedBranch)
            }
        } else {
            NavigationLink(destination: CodeEditorView(
                owner: repository.ownerName,
                repo: repository.name,
                path: file.path,
                branch: selectedBranch,
                fileName: file.name
            )) {
                FileRow(file: file, owner: repository.ownerName, repo: repository.name, branch: selectedBranch)
            }
            .contextMenu {
                contextMenuContent(for: file)
            }
        }
    }

    // 切换文件选择状态
    private func toggleFileSelection(_ file: FileItem) {
        if selectedFilesForDelete.contains(file.path) {
            selectedFilesForDelete.remove(file.path)
        } else {
            selectedFilesForDelete.insert(file.path)
        }
    }

    @ViewBuilder
    private func contextMenuContent(for file: FileItem) -> some View {
        Button(action: {
            selectedFile = file
            downloadFile(file)
        }) {
            Label("下载文件", systemImage: "arrow.down.circle")
        }

        Button(action: {
            if let url = URL(string: file.htmlUrl ?? repository.htmlUrl) {
                UIApplication.shared.open(url)
            }
        }) {
            Label("在 GitHub 打开", systemImage: "safari")
        }

        Button(action: {
            if let url = URL(string: file.downloadUrl ?? "") {
                UIApplication.shared.open(url)
            }
        }) {
            Label("复制下载链接", systemImage: "link")
        }
    }

    // MARK: - 下载文件

    private func downloadFile(_ file: FileItem) {
        guard let downloadUrl = file.downloadUrl else {
            errorMessage = "该文件不支持下载"
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadingFileName = file.name

        FileDownloadManager.shared.downloadAndShare(
            from: downloadUrl,
            fileName: file.name,
            progress: { progress in
                self.downloadProgress = progress
            }
        ) { result in
            self.isDownloading = false

            switch result {
            case .success:
                // 分享面板已自动弹出
                break
            case .failure(let error):
                self.errorMessage = "下载失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 上传文件

    // MARK: - 开始上传

    private func startUpload() {
        guard !selectedFiles.isEmpty else { return }

        showUploadConfirm = false
        isUploading = true
        uploadProgress = 0
        currentUploadIndex = 0
        totalUploadCount = selectedFiles.count

        uploadNextFile()
    }

    private func uploadNextFile() {
        guard currentUploadIndex < selectedFiles.count else {
            // 所有文件上传完成
            isUploading = false
            showUploadSuccess = true
            selectedFiles = []
            loadFiles()
            return
        }

        let fileURL = selectedFiles[currentUploadIndex]
        currentUploadFileName = fileURL.lastPathComponent

        uploadFile(at: fileURL) { success in
            if success {
                self.currentUploadIndex += 1
                self.uploadProgress = Double(self.currentUploadIndex) / Double(self.totalUploadCount)
                self.uploadNextFile()
            } else {
                // 上传失败，停止后续上传
                self.isUploading = false
            }
        }
    }

    private func uploadFile(at fileURL: URL, completion: @escaping (Bool) -> Void) {
        // 停止访问安全资源
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let fileData = try? Data(contentsOf: fileURL) else {
            uploadErrorMessage = "无法读取文件内容"
            completion(false)
            return
        }

        let fileName = fileURL.lastPathComponent
        let uploadPath = currentPath.isEmpty ? fileName : "\(currentPath)/\(fileName)"

        GitHubAPI.shared.uploadFileData(
            owner: repository.ownerName,
            repo: repository.name,
            path: uploadPath,
            fileData: fileData,
            message: "上传文件: \(fileName)（通过iOS客户端）",
            branch: selectedBranch
        ) { result in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                self.uploadErrorMessage = Self.formatUploadError(error, fileName: fileName)
                completion(false)
            }
        }
    }

    // MARK: - 创建文件夹

    private func createFolder(folderName: String) {
        let trimmedFolderName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFolderName.isEmpty else { return }

        isCreatingFolder = true
        showCreateFolderDialog = false

        let folderPath = currentPath.isEmpty ? trimmedFolderName : "\(currentPath)/\(trimmedFolderName)"

        GitHubAPI.shared.createDirectory(
            owner: repository.ownerName,
            repo: repository.name,
            path: folderPath,
            branch: selectedBranch
        ) { result in
            DispatchQueue.main.async {
                isCreatingFolder = false
                switch result {
                case .success:
                    showCreateFolderSuccess = true
                case .failure(let error):
                    createFolderErrorMessage = "创建失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 新建文件

    private func createFile(fileName: String) {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFileName.isEmpty else { return }

        isCreatingFile = true
        showCreateFileDialog = false

        let filePath = currentPath.isEmpty ? trimmedFileName : "\(currentPath)/\(trimmedFileName)"

        GitHubAPI.shared.createFile(
            owner: repository.ownerName,
            repo: repository.name,
            path: filePath,
            content: "",
            message: "创建文件: \(trimmedFileName)",
            branch: selectedBranch
        ) { result in
            DispatchQueue.main.async {
                isCreatingFile = false
                switch result {
                case .success:
                    // 创建成功后直接跳转到编辑状态
                    newlyCreatedFilePath = filePath
                    navigateToEditor = true
                    // 同时刷新文件列表
                    loadFiles()
                case .failure(let error):
                    createFileErrorMessage = "创建失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 删除选中文件

    private func deleteSelectedFiles() {
        guard !selectedFilesForDelete.isEmpty else { return }

        isDeleting = true
        showDeleteConfirm = false

        let filesToDelete = files.filter { selectedFilesForDelete.contains($0.path) }
        let group = DispatchGroup()
        var deleteErrors: [String] = []
        var successCount = 0

        for file in filesToDelete {
            group.enter()

            GitHubAPI.shared.deleteFile(
                owner: repository.ownerName,
                repo: repository.name,
                path: file.path,
                sha: file.sha,
                message: "删除文件: \(file.name)",
                branch: selectedBranch
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        successCount += 1
                    case .failure(let error):
                        deleteErrors.append("\(file.name): \(error.localizedDescription)")
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            isDeleting = false
            isDeleteMode = false
            selectedFilesForDelete.removeAll()
            loadFiles()

            if deleteErrors.isEmpty {
                // 删除成功，可以显示一个提示
                print("成功删除 \(successCount) 个文件")
            } else {
                // 部分删除失败，显示错误信息
                errorMessage = "部分文件删除失败:\n\(deleteErrors.joined(separator: "\n"))"
            }
        }
    }

    // MARK: - 格式化上传错误信息

    private static func formatUploadError(_ error: Error, fileName: String) -> String {
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("401") || errorDescription.contains("unauthorized") {
            return "上传失败：Token 无效或已过期，请重新登录后再试"
        } else if errorDescription.contains("403") || errorDescription.contains("forbidden") {
            return "上传失败：没有权限上传文件到该仓库，请检查仓库权限设置"
        } else if errorDescription.contains("404") || errorDescription.contains("not found") {
            return "上传失败：仓库或分支不存在，请检查仓库地址和分支名称"
        } else if errorDescription.contains("422") || errorDescription.contains("unprocessable") {
            return "上传失败：文件名包含非法字符或文件已存在，请修改文件名后再试"
        } else if errorDescription.contains("500") || errorDescription.contains("server error") {
            return "上传失败：GitHub 服务器暂时不可用，请稍后再试"
        } else if errorDescription.contains("network") || errorDescription.contains("timeout") || errorDescription.contains("offline") {
            return "上传失败：网络连接异常，请检查网络连接后再试"
        } else if errorDescription.contains("too large") || errorDescription.contains("size limit") {
            return "上传失败：文件大小超过 GitHub 限制（单个文件最大 100MB）"
        } else {
            return "上传「\(fileName)」失败：\(error.localizedDescription)\n\n请检查网络连接和 Token 权限后重试"
        }
    }
}

// MARK: - 文件行

struct FileRow: View {
    let file: FileItem
    let owner: String
    let repo: String
    let branch: String

    @State private var lastCommit: Commit?
    @State private var isLoadingCommit: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.iconName)
                .foregroundColor(file.isDirectory ? .blue : .gray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                if !file.isDirectory {
                    HStack(spacing: 8) {
                        Text(file.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.gray)

                        if let commit = lastCommit {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(commit.commit.committer.relativeDate)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        } else if isLoadingCommit {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("加载中...")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                }
            }

            Spacer()

            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadLastCommit()
        }
    }

    private func loadLastCommit() {
        guard file.isFile else { return }
        guard !isLoadingCommit else { return }

        // 先检查缓存
        if let cachedCommit = LastCommitCache.shared.getLastCommit(
            owner: owner,
            repo: repo,
            path: file.path,
            branch: branch
        ) {
            lastCommit = cachedCommit
            return
        }

        isLoadingCommit = true

        GitHubAPI.shared.getFileLastCommit(
            owner: owner,
            repo: repo,
            path: file.path,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isLoadingCommit = false
                switch result {
                case .success(let commit):
                    lastCommit = commit
                    // 存入缓存
                    LastCommitCache.shared.setLastCommit(
                        commit,
                        owner: owner,
                        repo: repo,
                        path: file.path,
                        branch: branch
                    )
                case .failure:
                    break
                }
            }
        }
    }
}

// MARK: - 分支选择器

struct BranchPickerView: View {
    let branches: [Branch]
    @Binding var selectedBranch: String
    let onSelect: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(branches) { branch in
                Button(action: {
                    selectedBranch = branch.name
                    onSelect()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.purple)
                        Text(branch.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedBranch == branch.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                        if branch.protected {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("选择分支")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 提交记录

struct CommitsView: View {
    let owner: String
    let repo: String
    @State private var commits: [Commit] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载提交记录...")
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.secondary)
                } else {
                    List(commits) { commit in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(commit.message)
                                .font(.subheadline)
                                .lineLimit(2)
                            HStack {
                                Text(commit.shortSha)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.blue)
                                Text("·")
                                    .foregroundColor(.gray)
                                Text(commit.authorName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(commit.formattedDate)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("提交记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        // 关闭sheet
                    }
                }
            }
        }
        .onAppear {
            loadCommits()
        }
    }
    
    private func loadCommits() {
        GitHubAPI.shared.getCommits(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let commits):
                    self.commits = commits
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct FileBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        FileBrowserView(repository: Repository(
            id: 1, name: "test", fullName: "test/test",
            description: "测试仓库", language: "Swift",
            stargazersCount: 0, forksCount: 0, watchersCount: 0,
            openIssuesCount: 0, isPrivate: false, htmlUrl: "",
            defaultBranch: "main", updatedAt: "", createdAt: "",
            owner: RepositoryOwner(login: "test", id: 1, avatarUrl: "")
        ))
    }
}
