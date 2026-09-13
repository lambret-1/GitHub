import SwiftUI

// MARK: - 提交详情视图
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 提交头部信息
                commitHeader

                // 提交统计
                commitStats

                Divider()

                // 变更文件列表
                changedFilesSection
            }
            .padding()
        }
        .navigationTitle("提交详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChangedFiles()
        }
        .sheet(item: $selectedFile) { file in
            FileDiffView(file: file)
        }
    }

    // MARK: - 提交头部信息
    private var commitHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 提交信息
            Text(commit.message)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(appState.isDarkMode ? .white : .primary)

            // 作者信息
            HStack(spacing: 10) {
                // 作者头像
                AsyncImage(url: URL(string: commit.author?.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(commit.authorName)
                        .font(.system(size: 15, weight: .semibold))
                    Text("提交于 \(commit.formattedDate)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 提交哈希
                VStack(alignment: .trailing, spacing: 2) {
                    Text("提交哈希")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(commit.shortSha)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
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
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
            .cornerRadius(6)
        }
    }

    // MARK: - 提交统计
    private var commitStats: some View {
        HStack(spacing: 16) {
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
            Text("变更文件 (\(changedFiles.count))")
                .font(.system(size: 16, weight: .semibold))

            if isLoadingFiles {
                HStack {
                    Spacer()
                    ProgressView("加载变更文件...")
                    Spacer()
                }
                .padding()
            } else if let error = filesError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
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
                .padding()
            } else if changedFiles.isEmpty {
                Text("暂无变更文件")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(changedFiles) { file in
                    ChangedFileRow(file: file)
                        .onTapGesture {
                            selectedFile = file
                        }

                    if file.id != changedFiles.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - 计算总新增行数
    private var totalAdditions: Int {
        return changedFiles.reduce(0) { $0 + ($1.additions ?? 0) }
    }

    // MARK: - 计算总删除行数
    private var totalDeletions: Int {
        return changedFiles.reduce(0) { $0 + ($1.deletions ?? 0) }
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

// MARK: - 变更文件行视图
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
                Text(file.filename)
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
        .padding(.vertical, 6)
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

    // MARK: - 文件路径
    private var filePath: String {
        return (file.filename as NSString).deletingLastPathComponent
    }
}

// MARK: - 文件Diff视图
struct FileDiffView: View {
    let file: ChangedFile
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 文件头部
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.blue)
                        Text(file.filename)
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
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
            .navigationTitle("文件变更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 关闭sheet
                    }
                }
            }
        }
    }

    // MARK: - Diff内容渲染
    private func diffContent(_ patch: String) -> some View {
        let lines = patch.components(separatedBy: .newlines)
        return VStack(alignment: .leading, spacing: 0) {
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
}
