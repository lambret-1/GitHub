import SwiftUI

// MARK: - HTML内容缓存

/// HTML内容缓存，避免重复下载
class HTMLCache {
    static let shared = HTMLCache()

    private struct CacheEntry {
        let content: String
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.github.htmlcache", attributes: .concurrent)
    private let cacheValidity: TimeInterval = 300 // 缓存有效期5分钟

    private init() {}

    func getContent(for key: String) -> String? {
        cacheQueue.sync {
            guard let entry = cache[key] else { return nil }
            // 检查缓存是否过期
            guard Date().timeIntervalSince(entry.timestamp) < cacheValidity else {
                // 缓存过期，移除
                cacheQueue.async(flags: .barrier) {
                    self.cache.removeValue(forKey: key)
                }
                return nil
            }
            // 检查内容是否为空
            guard !entry.content.isEmpty else { return nil }
            return entry.content
        }
    }

    func setContent(_ content: String, for key: String) {
        // 空内容不缓存
        guard !content.isEmpty else { return }
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = CacheEntry(content: content, timestamp: Date())
        }
    }

    func removeContent(for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }

    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

struct FileBrowserView: View {
    let repository: Repository
    @EnvironmentObject var appState: AppState
    @State var files: [FileItem] = []
    @State var currentPath: String = ""
    @State var pathStack: [String] = []
    @State var isLoading: Bool = true
    @State var errorMessage: String?
    @State var branches: [Branch] = []
    @State var selectedBranch: String = ""
    @State var showBranchPicker: Bool = false
    @State var showCommits: Bool = false
    @State var showActions: Bool = false
    @State var showDocumentPicker: Bool = false
    @State var isUploading: Bool = false
    @State var uploadProgress: Double = 0
    @State var selectedFiles: [URL] = []
    @State var showUploadConfirm: Bool = false
    @State var currentUploadIndex: Int = 0
    @State var totalUploadCount: Int = 0
    @State var currentUploadFileName: String = ""
    @State var isDownloading: Bool = false
    @State var downloadProgress: Double = 0
    @State var downloadingFileName: String = ""
    @State var showActionSheet: Bool = false
    @State var selectedFile: FileItem?
    @State var showUploadSuccess: Bool = false
    @State var uploadErrorMessage: String?
    @State var showCreateFolderDialog: Bool = false
    @State var newFolderName: String = ""
    @State var isCreatingFolder: Bool = false
    @State var showCreateFolderSuccess: Bool = false
    @State var createFolderErrorMessage: String?

    // 新建文件相关状态
    @State var showCreateFileDialog: Bool = false
    @State var newFileName: String = ""
    @State var isCreatingFile: Bool = false
    @State var showCreateFileSuccess: Bool = false
    @State var createFileErrorMessage: String?

    // 删除文件相关状态
    @State var isDeleteMode: Bool = false
    @State var selectedFilesForDelete: Set<String> = []
    @State var isDeleting: Bool = false
    @State var showDeleteConfirm: Bool = false

    // 新创建文件路径，用于跳转到编辑状态
    @State var newlyCreatedFilePath: String?
    @State var navigateToEditor: Bool = false

    // contextMenu编辑文件相关状态
    @State var contextMenuEditFilePath: String?
    @State var contextMenuEditFileName: String?
    @State var navigateToEditorFromContextMenu: Bool = false

    // contextMenu删除单个文件相关状态
    @State var contextMenuDeleteFile: FileItem?
    @State var showContextMenuDeleteConfirm: Bool = false
    @State var isDeletingSingleFile: Bool = false

    // contextMenu重命名文件相关状态
    @State var contextMenuRenameFile: FileItem?
    @State var showContextMenuRename: Bool = false
    @State var renameNewFileName: String = ""
    @State var isRenamingFile: Bool = false

    // HTML网页预览相关状态
    @State var showHTMLPreview: Bool = false
    @State var htmlPreviewContent: String = ""
    @State var htmlPreviewTitle: String = ""
    @State var isLoadingHTML: Bool = false
    @State var htmlPreviewError: String?
    @State var htmlPreviewURL: String = "" // 保存当前预览的URL，用于刷新

    // 仓库交互相关状态（星标、Fork）
    @State var isStarred: Bool = false
    @State var isCheckingStar: Bool = false
    @State var isStarring: Bool = false
    @State var isForking: Bool = false
    @State var showOperationMessage: Bool = false
    @State var operationMessage: String = ""

    // MARK: - README相关状态
    @State var readmeContent: String?
    @State var isLoadingReadme: Bool = false
    @State var readmeError: String?

    // MARK: - 下载ZIP相关状态
    @State var isDownloadingZip: Bool = false
    @State var zipDownloadProgress: Double = 0
    @State var showZipDownloadAlert: Bool = false
    @State var zipDownloadMessage: String = ""

    var body: some View {
        mainContent
    }

    // MARK: - 主要内容（拆分成单独属性，避免body表达式过于复杂导致类型检查超时）

    var mainContent: some View {
        baseView
            .modifier(FileBrowserHTMLSheetsModifier(view: self))
            .modifier(FileBrowserBranchAndRenameSheetsModifier(view: self))
            .modifier(FileBrowserUploadSheetsModifier(view: self))
            .modifier(FileBrowserCreateFolderSheetsModifier(view: self))
            .modifier(FileBrowserCreateFileSheetsModifier(view: self))
            .modifier(FileBrowserDeleteSheetsModifier(view: self))
    }

    // MARK: - 基础视图（拆分成单独属性，避免类型检查超时）

    var baseView: some View {
        VStack(spacing: 0) {
            // 仓库头部（复刻GitHub网页布局）
            RepoHeaderView(
                repository: repository,
                isStarred: isStarred,
                isCheckingStar: isCheckingStar,
                isStarring: isStarring,
                isForking: isForking,
                onToggleStar: toggleStar,
                onFork: forkRepository
            )
            .environmentObject(appState)

            // 分支栏（复刻GitHub网页布局）
            BranchBarView(
                branches: branches,
                selectedBranch: $selectedBranch,
                onBranchChange: {
                    loadFiles()
                },
                onDownloadZip: downloadRepositoryZip
            )
            .environmentObject(appState)

            // 路径导航栏（仅子目录显示）
            if !currentPath.isEmpty {
                pathNavigationBar
            }

            fileListContent

            // 删除模式底部操作栏
            if isDeleteMode {
                deleteActionBar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        // 隐藏的NavigationLink（拆分成单独属性，简化body表达式，避免类型检查超时）
        .background(hiddenNavigationLinks)
        .overlay {
            progressOverlay
        }
        .onAppear {
            if selectedBranch.isEmpty {
                selectedBranch = repository.defaultBranch ?? "main"
            }
            loadBranches()
            loadFiles()
            // 检查星标状态（仅别人的仓库）
            if !isOwnRepository {
                checkStarredStatus()
            }
        }
        // 操作提示消息
        .overlay(
            VStack {
                if showOperationMessage {
                    Text(operationMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut, value: showOperationMessage)
                }
                Spacer()
            }
        )
        // 下载ZIP进度遮罩
        .overlay(
            Group {
                if isDownloadingZip {
                    VStack(spacing: 16) {
                        ProgressView(value: zipDownloadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                        Text(zipDownloadMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                }
            }
        )
        // 下载ZIP结果弹窗
        .alert("下载提示", isPresented: $showZipDownloadAlert) {
            Button("确定", role: .cancel) {
                showZipDownloadAlert = false
            }
        } message: {
            Text(zipDownloadMessage)
        }
    }
    
    // MARK: - 隐藏的导航链接（拆分成单独属性，避免body表达式过于复杂导致类型检查超时）

    @ViewBuilder
    var hiddenNavigationLinks: some View {
        // 隐藏的NavigationLink，用于创建文件成功后跳转到编辑状态
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

        // 隐藏的NavigationLink，用于contextMenu中编辑文件跳转
        NavigationLink(destination: Group {
            if let filePath = contextMenuEditFilePath, let fileName = contextMenuEditFileName {
                CodeEditorView(
                    owner: repository.ownerName,
                    repo: repository.name,
                    path: filePath,
                    branch: selectedBranch,
                    fileName: fileName,
                    autoEnterEditMode: true // 自动进入编辑模式
                )
            }
        }, isActive: $navigateToEditorFromContextMenu) {
            EmptyView()
        }
        .hidden()

        // 隐藏的NavigationLink，用于Actions页面跳转
        NavigationLink(destination: ActionsListView(
            owner: repository.ownerName,
            repo: repository.name
        ), isActive: $showActions) {
            EmptyView()
        }
        .hidden()
    }

    // MARK: - 文件列表内容

    @ViewBuilder
    var fileListContent: some View {
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

    var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("加载中...")
            Spacer()
        }
    }

    func errorView(error: String) -> some View {
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

    var emptyView: some View {
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

    var fileListView: some View {
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
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            ForEach(files.sorted(by: { $0.isDirectory && !$1.isDirectory })) { file in
                fileRowView(for: file)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible)
            }

            // README显示区域（仅根目录显示）
            if currentPath.isEmpty {
                Section {
                    readmeSectionView
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
        // 下拉刷新功能，识别区在列表顶部（上半屏）
        .refreshable {
            await loadFilesAsync()
        }
    }

    // README显示区域
    var readmeSectionView: some View {
        Group {
            if isLoadingReadme {
                HStack {
                    Spacer()
                    ProgressView("加载README...")
                        .padding()
                    Spacer()
                }
            } else if let readmeContent = readmeContent {
                ReadmeView(markdownContent: readmeContent, owner: repository.ownerName, repo: repository.name, branch: selectedBranch.isEmpty ? "main" : selectedBranch)
                    .environmentObject(appState)
                    .listRowInsets(EdgeInsets())
            } else if let readmeError = readmeError {
                HStack {
                    Spacer()
                    Text("README加载失败: \(readmeError)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            }
        }
    }

    // 异步加载文件，用于下拉刷新
    func loadFilesAsync() async {
        await withCheckedContinuation { continuation in
            loadFiles {
                // 最小延迟确保刷新动画流畅
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - 删除模式底部操作栏

    var deleteActionBar: some View {
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
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            moreMenu
        }
    }

    // MARK: - HTML预览Sheet（拆分成单独属性，简化body表达式，避免类型检查超时）

    func htmlPreviewSheet() -> some View {
        NavigationView {
            HTMLPreviewView(
                htmlContent: htmlPreviewContent,
                title: htmlPreviewTitle,
                onRefresh: {
                    // 刷新网页：清除缓存，重新下载
                    let currentURL = htmlPreviewURL
                    let currentTitle = htmlPreviewTitle
                    HTMLCache.shared.removeContent(for: currentURL)
                    // 重新下载HTML内容
                    downloadHTMLFromURLForRefresh(currentURL, fileName: currentTitle)
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showHTMLPreview = false
                    }
                }
            }
        }
    }

    // MARK: - 重命名文件Sheet（拆分成单独属性，简化body表达式，避免类型检查超时）

    func renameFileSheet() -> some View {
        NavigationView {
            Form {
                Section("文件名") {
                    TextField("输入新的文件名", text: $renameNewFileName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section {
                    Button(action: {
                        if let file = contextMenuRenameFile {
                            renameFile(file, newName: renameNewFileName)
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isRenamingFile {
                                ProgressView()
                            } else {
                                Text("确认重命名")
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                    }
                    .disabled(renameNewFileName.isEmpty || isRenamingFile)
                }
            }
            .navigationTitle("重命名文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showContextMenuRename = false
                        contextMenuRenameFile = nil
                    }
                }
            }
        }
    }

    // MARK: - 更多菜单

    var moreMenu: some View {
        Menu {
            if isOwnRepository {
                // 自己的仓库：显示文件操作相关功能
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
            } else {
                // 别人的仓库：显示仓库交互相关功能
                Button(action: {
                    toggleStar()
                }) {
                    Label(isStarred ? "取消星标" : "添加星标", systemImage: isStarred ? "star.fill" : "star")
                }
                .disabled(isStarring || isCheckingStar)

                Button(action: {
                    forkRepository()
                }) {
                    Label("Fork 仓库", systemImage: "arrow.triangle.branch")
                }
                .disabled(isForking)

                Button(action: {
                    copyRepositoryURL()
                }) {
                    Label("复制仓库地址", systemImage: "link")
                }

                Divider()
            }

            // 通用功能（自己和别人的仓库都显示）
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
                showActions = true
            }) {
                Label("Actions", systemImage: "bolt.fill")
            }
            .disabled(isDeleteMode)

            Button(action: {
                downloadRepositoryZip()
            }) {
                Label("下载仓库 ZIP", systemImage: "square.and.arrow.down")
            }
            .disabled(isDeleteMode || isDownloadingZip)

            Button(action: {
                // 应用镜像加速转换
                let convertedURL = AppSettings.shared.convertWebURL(repository.htmlUrl)
                if let url = URL(string: convertedURL) {
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

    var uploadConfirmView: some View {
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

    func fileIcon(for url: URL) -> String {
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

    func fileIconColor(for url: URL) -> Color {
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

    func fileSizeString(for url: URL) -> String {
        guard let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = resources.fileSize else {
            return "未知大小"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    func removeSelectedFile(at offsets: IndexSet) {
        selectedFiles.remove(atOffsets: offsets)
    }

    // MARK: - 进度覆盖层

    @ViewBuilder
    var progressOverlay: some View {
        if isDownloading {
            downloadProgressView
        } else if isUploading {
            uploadProgressView
        }
    }

    var downloadProgressView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)

                Text("正在下载: \(downloadingFileName)")
                    .font(.headline)
                    .foregroundColor(.black)

                Text(String(format: "%.0f%%", downloadProgress * 100))
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
        }
    }

    var uploadProgressView: some View {
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
    var pathNavigationBar: some View {
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

    // MARK: - 仓库权限判断

    /// 判断当前仓库是否是用户自己的仓库
    var isOwnRepository: Bool {
        guard let currentUsername = AccountManager.shared.currentAccount?.username else {
            return false
        }
        return repository.ownerName.lowercased() == currentUsername.lowercased()
    }

    // MARK: - 星标相关方法

    /// 检查仓库是否已被星标
    func checkStarredStatus() {
        guard !isOwnRepository else { return }
        isCheckingStar = true
        GitHubAPI.shared.checkStarred(owner: repository.ownerName, repo: repository.name) { result in
            DispatchQueue.main.async {
                isCheckingStar = false
                switch result {
                case .success(let starred):
                    isStarred = starred
                case .failure:
                    break
                }
            }
        }
    }

    /// 切换星标状态
    func toggleStar() {
        if isStarred {
            unstarRepository()
        } else {
            starRepository()
        }
    }

    /// 星标仓库
    func starRepository() {
        isStarring = true
        GitHubAPI.shared.starRepository(owner: repository.ownerName, repo: repository.name) { result in
            DispatchQueue.main.async {
                isStarring = false
                switch result {
                case .success:
                    isStarred = true
                    showMessage("已添加星标")
                case .failure(let error):
                    showMessage("星标失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 取消星标仓库
    func unstarRepository() {
        isStarring = true
        GitHubAPI.shared.unstarRepository(owner: repository.ownerName, repo: repository.name) { result in
            DispatchQueue.main.async {
                isStarring = false
                switch result {
                case .success:
                    isStarred = false
                    showMessage("已取消星标")
                case .failure(let error):
                    showMessage("取消星标失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Fork 相关方法

    /// Fork 仓库
    func forkRepository() {
        isForking = true
        GitHubAPI.shared.forkRepository(owner: repository.ownerName, repo: repository.name) { result in
            DispatchQueue.main.async {
                isForking = false
                switch result {
                case .success:
                    showMessage("Fork 成功，已在您的账户下创建副本")
                case .failure(let error):
                    showMessage("Fork 失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 复制仓库地址

    /// 复制仓库地址到剪贴板
    func copyRepositoryURL() {
        let repoURL = "https://github.com/\(repository.ownerName)/\(repository.name)"
        UIPasteboard.general.string = repoURL
        showMessage("仓库地址已复制")
    }

    // MARK: - 提示消息

    /// 显示操作提示消息
    func showMessage(_ message: String) {
        operationMessage = message
        showOperationMessage = true
        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showOperationMessage = false
        }
    }

    func loadFiles(completion: (() -> Void)? = nil) {
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
                // 根目录时加载README
                if self.currentPath.isEmpty {
                    self.loadReadme()
                } else {
                    self.readmeContent = nil
                }
                completion?()
            }
        }
    }

    /// 加载仓库README内容
    func loadReadme() {
        isLoadingReadme = true
        readmeError = nil
        readmeContent = nil

        GitHubAPI.shared.getReadme(
            owner: repository.ownerName,
            repo: repository.name,
            branch: selectedBranch.isEmpty ? nil : selectedBranch
        ) { result in
            DispatchQueue.main.async {
                isLoadingReadme = false
                switch result {
                case .success(let content):
                    self.readmeContent = content
                case .failure(let error):
                    // 404表示没有README，不显示错误
                    if (error as NSError).code != 404 {
                        self.readmeError = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - 下载仓库ZIP

    func downloadRepositoryZip() {
        isDownloadingZip = true
        zipDownloadProgress = 0
        zipDownloadMessage = "正在准备下载..."

        let branch = selectedBranch.isEmpty ? "main" : selectedBranch
        // 使用GitHub官方zipball API，支持镜像加速
        let apiUrl = "https://api.github.com/repos/\(repository.ownerName)/\(repository.name)/zipball/\(branch)"
        // 应用镜像加速转换（如果开启了镜像加速）
        let downloadUrl = AppSettings.shared.convertDownloadURL(apiUrl)

        guard let url = URL(string: downloadUrl) else {
            isDownloadingZip = false
            zipDownloadMessage = "下载链接无效"
            showZipDownloadAlert = true
            return
        }

        var request = URLRequest(url: url)
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("GitHub-iOS-Client", forHTTPHeaderField: "User-Agent")

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: ZipDownloadDelegate(view: self), delegateQueue: nil)

        let task = session.downloadTask(with: request)
        task.resume()
    }

    // ZIP下载完成处理
    func handleZipDownloadFinished(location: URL, response: URLResponse?) {
        DispatchQueue.main.async {
            isDownloadingZip = false

            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                zipDownloadMessage = "下载失败：服务器返回错误 \(httpResponse.statusCode)"
                showZipDownloadAlert = true
                return
            }

            // 生成文件名：仓库名-分支名.zip
            let branch = selectedBranch.isEmpty ? "main" : selectedBranch
            let fileName = "\(repository.name)-\(branch).zip"

            // 移动到临时目录
            let tempDir = FileManager.default.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)

                // 使用iOS原生分享功能
                let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    // 分享完成后清理临时文件
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                }

                // 找到当前窗口的根视图控制器
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    // 找到最顶层的视图控制器
                    var topVC = rootVC
                    while let presentedVC = topVC.presentedViewController {
                        topVC = presentedVC
                    }
                    topVC.present(activityVC, animated: true)
                }

                zipDownloadMessage = "下载完成，已打开分享面板"
                showZipDownloadAlert = true
            } catch {
                zipDownloadMessage = "保存文件失败：\(error.localizedDescription)"
                showZipDownloadAlert = true
            }
        }
    }

    func handleZipDownloadProgress(progress: Double) {
        DispatchQueue.main.async {
            zipDownloadProgress = progress
            zipDownloadMessage = "正在下载... \(Int(progress * 100))%"
        }
    }

    func handleZipDownloadError(error: Error) {
        DispatchQueue.main.async {
            isDownloadingZip = false
            zipDownloadMessage = "下载失败：\(error.localizedDescription)"
            showZipDownloadAlert = true
        }
    }

    func loadBranches() {
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
    
    func navigateToDirectory(_ path: String) {
        pathStack.append(currentPath)
        currentPath = path
        loadFiles()
    }
    
    func navigateUp() {
        if let previousPath = pathStack.popLast() {
            currentPath = previousPath
        } else {
            currentPath = ""
        }
        loadFiles()
    }

    // MARK: - 文件行视图

    @ViewBuilder
    func fileRowView(for file: FileItem) -> some View {
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
    func toggleFileSelection(_ file: FileItem) {
        if selectedFilesForDelete.contains(file.path) {
            selectedFilesForDelete.remove(file.path)
        } else {
            selectedFilesForDelete.insert(file.path)
        }
    }

    @ViewBuilder
    func contextMenuContent(for file: FileItem) -> some View {
        // 编辑文件选项
        Button(action: {
            contextMenuEditFilePath = file.path
            contextMenuEditFileName = file.name
            navigateToEditorFromContextMenu = true
        }) {
            Label("编辑文件", systemImage: "pencil")
        }

        // 重命名文件选项（仅文件类型，文件夹不支持）
        if file.isFile {
            Button(action: {
                contextMenuRenameFile = file
                renameNewFileName = file.name
                showContextMenuRename = true
            }) {
                Label("重命名", systemImage: "pencil.line")
            }
        }

        // HTML文件显示网页预览选项
        if file.name.lowercased().hasSuffix(".html") || file.name.lowercased().hasSuffix(".htm") {
            Button(action: {
                previewHTMLFile(file)
            }) {
                Label("网页预览", systemImage: "globe")
            }
        }

        Button(action: {
            selectedFile = file
            downloadFile(file)
        }) {
            Label("下载文件", systemImage: "arrow.down.circle")
        }

        Button(action: {
            // 应用镜像加速转换
            let originalURL = file.htmlUrl ?? repository.htmlUrl
            let convertedURL = AppSettings.shared.convertWebURL(originalURL)
            if let url = URL(string: convertedURL) {
                UIApplication.shared.open(url)
            }
        }) {
            Label("在 GitHub 打开", systemImage: "safari")
        }

        Button(action: {
            if let url = URL(string: file.downloadUrl ?? "") {
                UIPasteboard.general.string = url.absoluteString
            }
        }) {
            Label("复制下载链接", systemImage: "link")
        }

        // 删除选项（红色字体）
        Button(action: {
            contextMenuDeleteFile = file
            showContextMenuDeleteConfirm = true
        }) {
            Label("删除", systemImage: "trash")
        }
        .foregroundColor(.red)
    }

    // MARK: - HTML网页预览

    func previewHTMLFile(_ file: FileItem) {
        // 优先使用download_url下载文件内容
        if let downloadUrl = file.downloadUrl, !downloadUrl.isEmpty {
            downloadHTMLFromURL(downloadUrl, fileName: file.name)
        } else {
            // 如果download_url为空，使用GitHub raw内容URL
            let rawUrl = "https://raw.githubusercontent.com/\(repository.ownerName)/\(repository.name)/\(selectedBranch)/\(file.path)"
            downloadHTMLFromURL(rawUrl, fileName: file.name)
        }
    }

    /// 从下载URL获取HTML内容
    func downloadHTMLFromURL(_ url: String, fileName: String) {
        // 保存当前预览的URL，用于刷新
        htmlPreviewURL = url

        // 先检查缓存
        if let cachedContent = HTMLCache.shared.getContent(for: url) {
            htmlPreviewContent = cachedContent
            htmlPreviewTitle = fileName
            showHTMLPreview = true
            return
        }

        isLoadingHTML = true
        htmlPreviewTitle = fileName
        htmlPreviewError = nil

        // 应用镜像加速转换
        let convertedURL = AppSettings.shared.convertDownloadURL(url)

        // 添加超时处理，确保请求不会一直挂起（10秒超时）
        guard let urlObj = URL(string: convertedURL) else {
            isLoadingHTML = false
            htmlPreviewError = "无效的下载链接"
            return
        }

        // 使用镜像专用URLSession，允许无效证书（镜像站点可能证书无效）
        var request = URLRequest(url: urlObj)
        request.timeoutInterval = 10
        request.cachePolicy = .returnCacheDataElseLoad
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        // 启用压缩传输
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        URLSession.mirrorSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingHTML = false

                if let error = error {
                    self.htmlPreviewError = "加载失败：\(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    self.htmlPreviewError = "加载失败：服务器返回错误 \(statusCode)"
                    return
                }

                // 尝试UTF8解码
                if let content = String(data: data, encoding: .utf8) {
                    // 缓存内容
                    HTMLCache.shared.setContent(content, for: url)
                    self.htmlPreviewContent = content
                    self.showHTMLPreview = true
                } else {
                    self.htmlPreviewError = "HTML文件编码不支持"
                }
            }
        }.resume()
    }

    /// 刷新时重新下载HTML内容（不检查缓存，直接下载）
    func downloadHTMLFromURLForRefresh(_ url: String, fileName: String) {
        // 不检查缓存，直接下载
        isLoadingHTML = true
        htmlPreviewTitle = fileName
        htmlPreviewError = nil

        // 应用镜像加速转换
        let convertedURL = AppSettings.shared.convertDownloadURL(url)

        guard let urlObj = URL(string: convertedURL) else {
            isLoadingHTML = false
            htmlPreviewError = "无效的下载链接"
            return
        }

        // 使用镜像专用URLSession，允许无效证书（镜像站点可能证书无效）
        var request = URLRequest(url: urlObj)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData // 忽略缓存，强制重新下载
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        URLSession.mirrorSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingHTML = false

                if let error = error {
                    self.htmlPreviewError = "刷新失败：\(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    self.htmlPreviewError = "刷新失败：服务器返回错误 \(statusCode)"
                    return
                }

                // 尝试UTF8解码
                if let content = String(data: data, encoding: .utf8) {
                    // 缓存内容
                    HTMLCache.shared.setContent(content, for: url)
                    // 更新当前预览内容（不重新打开页面）
                    self.htmlPreviewContent = content
                } else {
                    self.htmlPreviewError = "HTML文件编码不支持"
                }
            }
        }.resume()
    }

    // MARK: - 下载文件

    func downloadFile(_ file: FileItem) {
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

    func startUpload() {
        guard !selectedFiles.isEmpty else { return }

        showUploadConfirm = false
        isUploading = true
        uploadProgress = 0
        currentUploadIndex = 0
        totalUploadCount = selectedFiles.count

        uploadNextFile()
    }

    func uploadNextFile() {
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

    func uploadFile(at fileURL: URL, completion: @escaping (Bool) -> Void) {
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

    func createFolder(folderName: String) {
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

    func createFile(fileName: String) {
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

    func deleteSelectedFiles() {
        guard !selectedFilesForDelete.isEmpty else { return }

        isDeleting = true
        showDeleteConfirm = false

        let itemsToProcess = files.filter { selectedFilesForDelete.contains($0.path) }

        // 分离文件和文件夹
        // GitHub API 不支持直接删除文件夹，只能删除文件
        let filesToDelete = itemsToProcess.filter { $0.isFile }
        let directoriesToSkip = itemsToProcess.filter { $0.isDirectory }

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

            var messages: [String] = []

            if successCount > 0 {
                messages.append("成功删除 \(successCount) 个文件")
            }

            if !directoriesToSkip.isEmpty {
                let dirNames = directoriesToSkip.map { $0.name }.joined(separator: "、")
                messages.append("以下文件夹无法直接删除（GitHub API 限制）：\(dirNames)\n如需删除文件夹，请进入文件夹后逐个删除其中的文件")
            }

            if !deleteErrors.isEmpty {
                messages.append("部分文件删除失败:\n\(deleteErrors.joined(separator: "\n"))")
            }

            if !messages.isEmpty {
                errorMessage = messages.joined(separator: "\n\n")
            }
        }
    }

    // MARK: - 删除单个文件（contextMenu）

    func deleteSingleFile(_ file: FileItem) {
        // GitHub API 不支持直接删除文件夹，只能删除文件
        if file.isDirectory {
            errorMessage = "无法直接删除文件夹「\(file.name)」（GitHub API 限制）\n如需删除文件夹，请进入文件夹后逐个删除其中的文件"
            contextMenuDeleteFile = nil
            return
        }

        isDeletingSingleFile = true
        contextMenuDeleteFile = nil

        GitHubAPI.shared.deleteFile(
            owner: repository.ownerName,
            repo: repository.name,
            path: file.path,
            sha: file.sha,
            message: "删除文件: \(file.name)",
            branch: selectedBranch
        ) { result in
            DispatchQueue.main.async {
                isDeletingSingleFile = false
                switch result {
                case .success:
                    // 删除成功，刷新文件列表
                    loadFiles()
                case .failure(let error):
                    // 删除失败，显示错误信息
                    errorMessage = "删除文件失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 重命名文件（contextMenu）

    func renameFile(_ file: FileItem, newName: String) {
        // 检查新文件名是否为空
        guard !newName.isEmpty else {
            errorMessage = "文件名不能为空"
            return
        }

        // 检查新文件名是否与旧文件名相同
        guard newName != file.name else {
            errorMessage = "新文件名与原文件名相同"
            return
        }

        isRenamingFile = true

        // 计算新文件的路径（替换文件名部分，保留目录路径）
        let oldPath = file.path
        let newPath: String
        if oldPath.contains("/") {
            // 文件在子目录中，替换最后一个路径组件
            let components = oldPath.components(separatedBy: "/")
            var newComponents = components
            newComponents[newComponents.count - 1] = newName
            newPath = newComponents.joined(separator: "/")
        } else {
            // 文件在根目录
            newPath = newName
        }

        GitHubAPI.shared.renameFile(
            owner: repository.ownerName,
            repo: repository.name,
            oldPath: oldPath,
            newPath: newPath,
            branch: selectedBranch
        ) { result in
            DispatchQueue.main.async {
                isRenamingFile = false
                showContextMenuRename = false
                contextMenuRenameFile = nil

                switch result {
                case .success:
                    // 重命名成功，刷新文件列表
                    loadFiles()
                case .failure(let error):
                    // 重命名失败，显示错误信息
                    errorMessage = "重命名文件失败: \(error.localizedDescription)"
                }
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

    @State var lastCommit: Commit?
    @State var isLoadingCommit: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 文件/文件夹图标
            Image(systemName: file.iconName)
                .foregroundColor(file.isDirectory ? Color(red: 0.18, green: 0.49, blue: 0.82) : Color.gray)
                .font(.system(size: 20))
                .frame(width: 28)

            // 文件/文件夹名称
            Text(file.name)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // 最后更新时间（右侧，灰色）
            if let commit = lastCommit {
                Text(commit.commit.committer.relativeDate)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else if isLoadingCommit {
                Text("加载中...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.5))
                    .lineLimit(1)
            } else {
                Text("--")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onAppear {
            loadLastCommit()
        }
    }

    func loadLastCommit() {
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

// MARK: - ZIP下载代理

class ZipDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var view: FileBrowserView?

    init(view: FileBrowserView) {
        self.view = view
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        view?.handleZipDownloadFinished(location: location, response: downloadTask.response)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            view?.handleZipDownloadProgress(progress: progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // 忽略取消错误
            if (error as NSError).code != NSURLErrorCancelled {
                view?.handleZipDownloadError(error: error)
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
    @State private var searchText: String = ""

    // 过滤后的分支列表
    private var filteredBranches: [Branch] {
        if searchText.isEmpty {
            return branches
        }
        return branches.filter { branch in
            branch.name.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索分支...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // 分支列表
                List {
                    if filteredBranches.isEmpty {
                        HStack {
                            Spacer()
                            Text("未找到匹配的分支")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                    } else {
                        ForEach(filteredBranches) { branch in
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
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("选择分支（共\(branches.count)个）")
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
    @State var commits: [Commit] = []
    @State var isLoading: Bool = true
    @State var errorMessage: String?
    
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
    
    func loadCommits() {
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

// MARK: - Sheet和Alert修饰符（拆分成多个小修饰符，避免类型检查超时）

private struct FileBrowserHTMLSheetsModifier: ViewModifier {
    let view: FileBrowserView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: view.$showHTMLPreview, content: view.htmlPreviewSheet)
            .alert("加载失败", isPresented: .constant(view.htmlPreviewError != nil)) {
                Button("确定") {
                    view.htmlPreviewError = nil
                }
            } message: {
                Text(view.htmlPreviewError ?? "未知错误")
            }
    }
}

private struct FileBrowserBranchAndRenameSheetsModifier: ViewModifier {
    let view: FileBrowserView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: view.$showBranchPicker) {
                BranchPickerView(branches: view.branches, selectedBranch: view.$selectedBranch) {
                    view.loadFiles()
                    view.showBranchPicker = false
                }
            }
            .sheet(isPresented: view.$showContextMenuRename, content: view.renameFileSheet)
            .sheet(isPresented: view.$showCommits) {
                CommitsView(owner: view.repository.ownerName, repo: view.repository.name)
            }
    }
}

private struct FileBrowserUploadSheetsModifier: ViewModifier {
    let view: FileBrowserView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: view.$showDocumentPicker) {
                DocumentPickerView(allowsMultipleSelection: true) { urls in
                    view.selectedFiles = urls
                    view.showUploadConfirm = true
                }
            }
            .sheet(isPresented: view.$showUploadConfirm) {
                view.uploadConfirmView
            }
            .alert("上传完成", isPresented: view.$showUploadSuccess) {
                Button("确定", role: .cancel) {
                    view.loadFiles()
                }
            } message: {
                Text("文件已成功上传到仓库")
            }
            .alert("上传失败", isPresented: .constant(view.uploadErrorMessage != nil)) {
                Button("确定", role: .cancel) {
                    view.uploadErrorMessage = nil
                }
            } message: {
                Text(view.uploadErrorMessage ?? "未知错误")
            }
    }
}

private struct FileBrowserCreateFolderSheetsModifier: ViewModifier {
    let view: FileBrowserView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: view.$showCreateFolderDialog) {
                CreateFolderView(currentPath: view.currentPath) { folderName in
                    view.createFolder(folderName: folderName)
                } onCancel: {
                    view.showCreateFolderDialog = false
                }
            }
            .alert("创建成功", isPresented: view.$showCreateFolderSuccess) {
                Button("确定") {
                    view.loadFiles()
                }
            } message: {
                Text("文件夹已成功创建")
            }
            .alert("创建失败", isPresented: .constant(view.createFolderErrorMessage != nil)) {
                Button("确定", role: .cancel) {
                    view.createFolderErrorMessage = nil
                }
            } message: {
                Text(view.createFolderErrorMessage ?? "未知错误")
            }
    }
}

private struct FileBrowserCreateFileSheetsModifier: ViewModifier {
    let view: FileBrowserView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: view.$showCreateFileDialog) {
                CreateFileView(currentPath: view.currentPath) { fileName in
                    view.createFile(fileName: fileName)
                } onCancel: {
                    view.showCreateFileDialog = false
                }
            }
            .alert("创建成功", isPresented: view.$showCreateFileSuccess) {
                Button("确定") {
                    view.loadFiles()
                }
            } message: {
                Text("文件已成功创建")
            }
            .alert("创建失败", isPresented: .constant(view.createFileErrorMessage != nil)) {
                Button("确定", role: .cancel) {
                    view.createFileErrorMessage = nil
                }
            } message: {
                Text(view.createFileErrorMessage ?? "未知错误")
            }
    }
}

private struct FileBrowserDeleteSheetsModifier: ViewModifier {
    let view: FileBrowserView

    func body(content: Content) -> some View {
        content
            .alert("确认删除", isPresented: view.$showContextMenuDeleteConfirm) {
                Button("取消", role: .cancel) {
                    view.contextMenuDeleteFile = nil
                }
                Button("删除", role: .destructive) {
                    if let file = view.contextMenuDeleteFile {
                        view.deleteSingleFile(file)
                    }
                }
            } message: {
                if let file = view.contextMenuDeleteFile {
                    Text("确定要删除文件「\(file.name)」吗？此操作不可撤销。")
                } else {
                    Text("确定要删除该文件吗？此操作不可撤销。")
                }
            }
            .alert("确认删除", isPresented: view.$showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    view.deleteSelectedFiles()
                }
            } message: {
                let selectedItems = view.files.filter { view.selectedFilesForDelete.contains($0.path) }
                let fileCount = selectedItems.filter { $0.isFile }.count
                let dirCount = selectedItems.filter { $0.isDirectory }.count
                if dirCount > 0 {
                    Text("确定要删除选中的 \(fileCount) 个文件吗？\n\n注意：选中的 \(dirCount) 个文件夹无法直接删除（GitHub API 限制），将被跳过。如需删除文件夹，请进入文件夹后逐个删除其中的文件。")
                } else {
                    Text("确定要删除选中的 \(fileCount) 个文件吗？此操作不可撤销。")
                }
            }
    }
}