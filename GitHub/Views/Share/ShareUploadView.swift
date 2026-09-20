import SwiftUI

// ==============================================================================
// ShareUploadView 分享文件上传确认视图
// 功能：展示从Share Extension接收的待上传文件，让用户选择仓库/分支/路径后上传
// 位置：主应用端，处理分享扩展文件的上传
// 设计原则：简洁高效，支持批量上传，与现有文件上传逻辑保持一致
// ==============================================================================

struct ShareUploadView: View {
    // MARK: - 环境对象

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态属性

    @ObservedObject private var shareFileManager = ShareFileManager.shared

    // 仓库列表
    @State private var repositories: [Repository] = []
    @State private var isLoadingRepos: Bool = true
    @State private var repoLoadError: String?

    // 选中的仓库
    @State private var selectedRepo: Repository?

    // 分支列表
    @State private var branches: [Branch] = []
    @State private var isLoadingBranches: Bool = false
    @State private var selectedBranch: String = "main"

    // 上传路径
    @State private var uploadPath: String = ""

    // 上传状态
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0
    @State private var currentUploadingFileName: String = ""
    @State private var uploadResults: [String: Bool] = [:] // 文件名: 是否成功
    @State private var showUploadResult: Bool = false

    // MARK: - 计算属性

    private var totalFileSize: Int64 {
        shareFileManager.pendingFiles.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            List {
                // 文件列表部分
                Section(header: Text("待上传文件（\(shareFileManager.pendingFiles.count)个）")) {
                    ForEach(shareFileManager.pendingFiles) { file in
                        HStack(spacing: 12) {
                            // 文件图标
                            Image(systemName: fileIcon(for: file.fileName))
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.fileName)
                                    .font(.system(size: 15, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                HStack(spacing: 8) {
                                    Text(shareFileManager.formattedFileSize(file.fileSize))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)

                                    Text(formatDate(file.receivedDate))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // 上传结果图标
                            if let success = uploadResults[file.fileName] {
                                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(success ? .green : .red)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 清空按钮
                    Button(action: {
                        shareFileManager.clearAllPendingFiles()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清空列表")
                        }
                        .foregroundColor(.red)
                    }
                }

                // 上传配置部分
                Section(header: Text("上传配置")) {
                    // 选择仓库
                    NavigationLink(destination: repoSelectionView) {
                        HStack {
                            Text("选择仓库")
                            Spacer()
                            if let repo = selectedRepo {
                                Text("\(repo.ownerName)/\(repo.name)")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("未选择")
                                    .foregroundColor(.gray)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }

                    // 选择分支
                    if selectedRepo != nil {
                        NavigationLink(destination: branchSelectionView) {
                            HStack {
                                Text("选择分支")
                                Spacer()
                                Text(selectedBranch)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    // 上传路径
                    HStack {
                        Text("上传路径")
                        TextField("根目录（留空表示根目录）", text: $uploadPath)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }

                // 上传按钮
                Section {
                    Button(action: {
                        startUpload()
                    }) {
                        HStack {
                            Spacer()
                            if isUploading {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("正在上传 \(currentUploadingFileName)...")
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                Text("开始上传（\(shareFileManager.pendingFiles.count)个文件）")
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(canUpload ? Color.blue : Color.gray)
                        .cornerRadius(8)
                    }
                    .disabled(!canUpload || isUploading)
                }
            }
            .navigationTitle("分享文件上传")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        // 取消时删除本次显示的文件所在的会话文件夹（文件夹隔离，不影响其他会话）
                        let sessionIDs = Set(shareFileManager.pendingFiles.map { $0.sessionID })
                        for sessionID in sessionIDs {
                            shareFileManager.removeSessionDirectory(sessionID: sessionID)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRepositories()
                shareFileManager.scanPendingFiles()
            }
            .alert("上传完成", isPresented: $showUploadResult) {
                Button("确定") {
                    let successCount = uploadResults.values.filter { $0 }.count
                    if successCount == uploadResults.count {
                        // 全部成功：删除本次上传涉及的所有会话文件夹（文件夹隔离，不影响其他会话）
                        let sessionIDs = Set(shareFileManager.pendingFiles.map { $0.sessionID })
                        for sessionID in sessionIDs {
                            shareFileManager.removeSessionDirectory(sessionID: sessionID)
                        }
                        dismiss()
                    }
                }
            } message: {
                let successCount = uploadResults.values.filter { $0 }.count
                let failCount = uploadResults.count - successCount
                return Text("成功：\(successCount)个，失败：\(failCount)个")
            }
        }
    }

    // MARK: - 仓库选择视图

    private var repoSelectionView: some View {
        List {
            if isLoadingRepos {
                HStack {
                    Spacer()
                    ProgressView("加载仓库列表...")
                    Spacer()
                }
            } else if let error = repoLoadError {
                Text(error)
                    .foregroundColor(.red)
            } else {
                ForEach(repositories) { repo in
                    Button(action: {
                        selectedRepo = repo
                        selectedBranch = "main"
                        loadBranches()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(repo.ownerName)/\(repo.name)")
                                    .font(.system(size: 15, weight: .medium))
                                if let desc = repo.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if selectedRepo?.id == repo.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("选择仓库")
    }

    // MARK: - 分支选择视图

    private var branchSelectionView: some View {
        List {
            if isLoadingBranches {
                HStack {
                    Spacer()
                    ProgressView("加载分支列表...")
                    Spacer()
                }
            } else {
                ForEach(branches) { branch in
                    Button(action: {
                        selectedBranch = branch.name
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.purple)
                            Text(branch.name)
                            Spacer()
                            if selectedBranch == branch.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("选择分支")
    }

    // MARK: - 计算属性

    private var canUpload: Bool {
        selectedRepo != nil && !shareFileManager.pendingFiles.isEmpty
    }

    // MARK: - 数据加载

    private func loadRepositories() {
        isLoadingRepos = true
        repoLoadError = nil

        GitHubAPI.shared.getUserRepos(perPage: 100) { result in
            DispatchQueue.main.async {
                isLoadingRepos = false
                switch result {
                case .success(let repos):
                    repositories = repos
                case .failure(let error):
                    repoLoadError = "加载仓库失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func loadBranches() {
        guard let repo = selectedRepo else { return }
        isLoadingBranches = true

        GitHubAPI.shared.getBranches(owner: repo.ownerName, repo: repo.name) { result in
            DispatchQueue.main.async {
                isLoadingBranches = false
                switch result {
                case .success(let branchList):
                    branches = branchList
                    if let first = branchList.first {
                        selectedBranch = first.name
                    }
                case .failure:
                    branches = []
                }
            }
        }
    }

    // MARK: - 上传逻辑

    private func startUpload() {
        guard let repo = selectedRepo else { return }
        isUploading = true
        uploadProgress = 0
        uploadResults = [:]

        let files = shareFileManager.pendingFiles
        let totalCount = files.count

        func uploadNext(index: Int) {
            guard index < files.count else {
                // 全部上传完成
                DispatchQueue.main.async {
                    isUploading = false
                    showUploadResult = true
                }
                return
            }

            let file = files[index]
            DispatchQueue.main.async {
                currentUploadingFileName = file.fileName
                uploadProgress = Double(index) / Double(totalCount)
            }

            // 读取文件内容
            do {
                let fileData = try Data(contentsOf: file.fileURL)
                let contentBase64 = fileData.base64EncodedString()

                // 构建上传路径
                var targetPath = uploadPath.trimmingCharacters(in: .whitespacesAndNewlines)
                if !targetPath.isEmpty && !targetPath.hasSuffix("/") {
                    targetPath += "/"
                }
                targetPath += file.fileName

                // 上传到GitHub
                GitHubAPI.shared.createFile(
                    owner: repo.ownerName,
                    repo: repo.name,
                    path: targetPath,
                    content: contentBase64,
                    message: "通过分享上传：\(file.fileName)（GitHub中文客户端）",
                    branch: selectedBranch
                ) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            uploadResults[file.fileName] = true
                        case .failure:
                            uploadResults[file.fileName] = false
                        }
                        uploadNext(index: index + 1)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    uploadResults[file.fileName] = false
                    uploadNext(index: index + 1)
                }
            }
        }

        uploadNext(index: 0)
    }

    // MARK: - 辅助方法

    private func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "bmp", "webp":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "zip", "rar", "7z":
            return "doc.zipper"
        case "txt", "md":
            return "doc.text"
        case "swift", "js", "py", "java", "kt", "go", "rs", "cpp", "c", "h":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
