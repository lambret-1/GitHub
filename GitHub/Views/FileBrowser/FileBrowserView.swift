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
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var downloadingFileName: String = ""
    @State private var showDownloadSuccess: Bool = false
    @State private var downloadedFileURL: URL?
    @State private var showActionSheet: Bool = false
    @State private var selectedFile: FileItem?
    @State private var showUploadSuccess: Bool = false
    @State private var uploadErrorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // 路径导航栏
            pathNavigationBar
            
            // 文件列表
            if isLoading {
                Spacer()
                ProgressView("加载中...")
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
                        loadFiles()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else if files.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("此目录为空")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    // 返回上一级
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
                        if file.isDirectory {
                            Button(action: {
                                navigateToDirectory(file.path)
                            }) {
                                FileRow(file: file)
                            }
                        } else {
                            NavigationLink(destination: CodeEditorView(
                                owner: repository.ownerName,
                                repo: repository.name,
                                path: file.path,
                                branch: selectedBranch,
                                fileName: file.name
                            )) {
                                FileRow(file: file)
                            }
                            .contextMenu {
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
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showDocumentPicker = true
                }) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isUploading || isDownloading)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showBranchPicker = true
                    }) {
                        Label("切换分支: \(selectedBranch)", systemImage: "arrow.triangle.branch")
                    }

                    Button(action: {
                        showCommits = true
                    }) {
                        Label("提交记录", systemImage: "clock.arrow.circlepath")
                    }

                    Button(action: {
                        if let url = URL(string: repository.htmlUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("在 GitHub 打开", systemImage: "safari")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
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
            DocumentPickerView { url in
                uploadFile(at: url)
            }
        }
        .alert("下载完成", isPresented: $showDownloadSuccess) {
            Button("分享文件") {
                if let fileURL = downloadedFileURL,
                   let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let viewController = windowScene.windows.first?.rootViewController {
                    FileDownloadManager.shared.shareFile(at: fileURL, from: viewController)
                }
            }
            Button("保存到文件", role: .default) {
                if let fileURL = downloadedFileURL,
                   let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let viewController = windowScene.windows.first?.rootViewController {
                    FileDownloadManager.shared.exportToFilesApp(at: fileURL, from: viewController)
                }
            }
            Button("确定", role: .cancel) {}
        } message: {
            if let fileURL = downloadedFileURL {
                Text("文件已下载: \(fileURL.lastPathComponent)")
            }
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
        .overlay {
            if isDownloading {
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

            if isUploading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("正在上传文件...")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("请稍候")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(.systemGray6).opacity(0.9))
                    .cornerRadius(16)
                }
            }
        }
        .onAppear {
            if selectedBranch.isEmpty {
                selectedBranch = repository.defaultBranch
            }
            loadBranches()
            loadFiles()
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

    // MARK: - 下载文件

    private func downloadFile(_ file: FileItem) {
        guard let downloadUrl = file.downloadUrl else {
            errorMessage = "该文件不支持下载"
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadingFileName = file.name

        FileDownloadManager.shared.downloadFile(
            from: downloadUrl,
            fileName: file.name,
            progress: { progress in
                self.downloadProgress = progress
            }
        ) { result in
            self.isDownloading = false

            switch result {
            case .success(let fileURL):
                self.downloadedFileURL = fileURL
                self.showDownloadSuccess = true
            case .failure(let error):
                self.errorMessage = "下载失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 上传文件

    private func uploadFile(at fileURL: URL) {
        // 停止访问安全资源
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let fileData = try? Data(contentsOf: fileURL) else {
            uploadErrorMessage = "无法读取文件内容"
            return
        }

        let fileName = fileURL.lastPathComponent
        let uploadPath = currentPath.isEmpty ? fileName : "\(currentPath)/\(fileName)"

        isUploading = true

        GitHubAPI.shared.uploadFileData(
            owner: repository.ownerName,
            repo: repository.name,
            path: uploadPath,
            fileData: fileData,
            message: "上传文件: \(fileName)（通过iOS客户端）",
            branch: selectedBranch
        ) { result in
            self.isUploading = false

            switch result {
            case .success:
                self.showUploadSuccess = true
            case .failure(let error):
                self.uploadErrorMessage = "上传失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 文件行

struct FileRow: View {
    let file: FileItem
    
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
                    Text(file.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.gray)
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
