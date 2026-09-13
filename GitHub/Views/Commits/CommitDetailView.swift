import SwiftUI

// MARK: - 提交详情视图（全新重构，对齐GitHub官方样式）
struct CommitDetailView: View {
    let owner: String
    let repo: String
    let commit: Commit
    @EnvironmentObject var appState: AppState

    // 变更文件状态
    @State private var changedFiles: [ChangedFile] = []
    @State private var isLoadingFiles: Bool = false
    @State private var filesError: String?

    // 选中的文件（用于查看diff）
    @State private var selectedFile: ChangedFile?

    // 操作提示
    @State private var operationMessage: String = ""
    @State private var showOperationMessage: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 提交头部信息
                commitHeader

                // 提交统计
                commitStats

                Divider()
                    .padding(.vertical, 8)

                // 变更文件列表
                changedFilesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(appState.isDarkMode ? Color.black : Color(.systemBackground))
        .navigationTitle("提交详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChangedFiles()
        }
        .sheet(item: $selectedFile) { file in
            FileDiffView(file: file)
        }
        .overlay {
            if showOperationMessage {
                VStack {
                    Spacer()
                    Text(operationMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            showOperationMessage = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - 提交头部信息
    private var commitHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 提交信息
            Text(commit.message)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(appState.isDarkMode ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)

            // 作者信息
            HStack(spacing: 10) {
                // 作者头像
                AsyncImage(url: URL(string: commit.author?.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(commit.authorName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(appState.isDarkMode ? .white : .primary)
                    Text("提交于 \(commit.formattedDate)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 提交哈希
                VStack(alignment: .trailing, spacing: 4) {
                    Text("提交哈希")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Button(action: {
                        UIPasteboard.general.string = commit.sha
                        operationMessage = "已复制完整提交哈希"
                        showOperationMessage = true
                    }) {
                        HStack(spacing: 4) {
                            Text(commit.shortSha)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 完整哈希
            HStack {
                Text(commit.sha)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer()

                Button(action: {
                    UIPasteboard.general.string = commit.sha
                    operationMessage = "已复制完整提交哈希"
                    showOperationMessage = true
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - 提交统计
    private var commitStats: some View {
        HStack(spacing: 20) {
            statItem(
                icon: "plus.circle.fill",
                color: .green,
                title: "新增",
                value: "\(totalAdditions)"
            )

            statItem(
                icon: "minus.circle.fill",
                color: .red,
                title: "删除",
                value: "\(totalDeletions)"
            )

            statItem(
                icon: "doc.fill",
                color: .blue,
                title: "文件",
                value: "\(changedFiles.count)"
            )

            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - 统计项
    private func statItem(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(appState.isDarkMode ? .white : .primary)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 变更文件列表
    private var changedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("变更文件")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                Text("(\(changedFiles.count))")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if isLoadingFiles {
                HStack {
                    Spacer()
                    ProgressView("加载变更文件...")
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if let error = filesError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        loadChangedFiles()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            } else if changedFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无变更文件")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            } else {
                ForEach(changedFiles) { file in
                    ChangedFileRow(file: file)
                        .onTapGesture {
                            selectedFile = file
                        }

                    if file.id != changedFiles.last?.id {
                        Divider()
                            .padding(.leading, 32)
                    }
                }
            }
        }
    }

    // MARK: - 计算总新增行数
    private var totalAdditions: Int {
        return changedFiles.reduce(0) { $0 + $1.additions }
    }

    // MARK: - 计算总删除行数
    private var totalDeletions: Int {
        return changedFiles.reduce(0) { $0 + $1.deletions }
    }

    // MARK: - 加载变更文件
    private func loadChangedFiles() {
        isLoadingFiles = true
        filesError = nil

        GitHubAPI.shared.getCommitFiles(owner: owner, repo: repo, sha: commit.sha) { result in
            DispatchQueue.main.async {
                isLoadingFiles = false
                switch result {
                case .success(let files):
                    changedFiles = files
                case .failure(let error):
                    filesError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - 变更文件行视图（全新重构，对齐GitHub官方样式）
struct ChangedFileRow: View {
    let file: ChangedFile
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            // 文件状态图标
            Image(systemName: statusIcon)
                .font(.system(size: 14))
                .foregroundColor(statusColor)
                .frame(width: 20)

            // 文件名
            VStack(alignment: .leading, spacing: 2) {
                Text(fileNameOnly)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .lineLimit(1)

                // 文件路径
                if !filePath.isEmpty {
                    Text(filePath)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 变更统计
            HStack(spacing: 8) {
                if file.additions > 0 {
                    Text("+\(file.additions)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }

                if file.deletions > 0 {
                    Text("-\(file.deletions)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - 状态图标
    private var statusIcon: String {
        switch file.status.lowercased() {
        case "added": return "plus.circle.fill"
        case "modified": return "pencil.circle.fill"
        case "removed": return "trash.circle.fill"
        case "renamed": return "arrow.left.arrow.right.circle.fill"
        default: return "doc.fill"
        }
    }

    // MARK: - 状态颜色
    private var statusColor: Color {
        switch file.status.lowercased() {
        case "added": return .green
        case "modified": return .blue
        case "removed": return .red
        case "renamed": return .orange
        default: return .gray
        }
    }

    // MARK: - 文件名（不含路径）
    private var fileNameOnly: String {
        return (file.filename as NSString).lastPathComponent
    }

    // MARK: - 文件路径
    private var filePath: String {
        return (file.filename as NSString).deletingLastPathComponent
    }
}

// MARK: - 文件Diff视图（全新重构，支持大文件流畅打开）
struct FileDiffView: View {
    let file: ChangedFile
    @EnvironmentObject var appState: AppState

    // 缩放比例
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 文件头部
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        Text(file.filename)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(appState.isDarkMode ? .white : .primary)
                            .lineLimit(1)
                        Spacer()
                        // 变更统计
                        HStack(spacing: 6) {
                            if file.additions > 0 {
                                Text("+\(file.additions)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            if file.deletions > 0 {
                                Text("-\(file.deletions)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))

                    // Diff内容
                    if let patch = file.patch, !patch.isEmpty {
                        diffContent(patch)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("此文件为二进制文件或无可用的Diff内容")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
            }
            .background(appState.isDarkMode ? Color.black : Color.white)
            .navigationTitle("文件变更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 关闭sheet
                    }
                }
            }
            // 双指缩放
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                        // 限制缩放范围
                        scale = max(0.5, min(scale, 2.0))
                    }
                    .onEnded { value in
                        lastScale = scale
                    }
            )
        }
    }

    // MARK: - Diff内容渲染（使用LazyVStack优化大文件性能）
    private func diffContent(_ patch: String) -> some View {
        let lines = patch.components(separatedBy: .newlines)
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 0) {
                    // 行号
                    Text("\(index + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                        .padding(.trailing, 8)

                    // 行内容
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(lineColor(line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(lineBackground(line))
            }
        }
        .padding(.vertical, 8)
        .scaleEffect(scale)
    }

    // MARK: - 行颜色
    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("+") {
            return .green
        } else if line.hasPrefix("-") {
            return .red
        } else if line.hasPrefix("@@") {
            return .blue
        } else {
            return appState.isDarkMode ? .white.opacity(0.8) : .primary
        }
    }

    // MARK: - 行背景
    private func lineBackground(_ line: String) -> Color {
        if line.hasPrefix("+") {
            return .green.opacity(0.1)
        } else if line.hasPrefix("-") {
            return .red.opacity(0.1)
        } else if line.hasPrefix("@@") {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }

    // MARK: - 状态图标
    private var statusIcon: String {
        switch file.status.lowercased() {
        case "added": return "plus.circle.fill"
        case "modified": return "pencil.circle.fill"
        case "removed": return "trash.circle.fill"
        case "renamed": return "arrow.left.arrow.right.circle.fill"
        default: return "doc.fill"
        }
    }

    // MARK: - 状态颜色
    private var statusColor: Color {
        switch file.status.lowercased() {
        case "added": return .green
        case "modified": return .blue
        case "removed": return .red
        case "renamed": return .orange
        default: return .gray
        }
    }
}
