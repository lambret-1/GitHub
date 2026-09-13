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
                    .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧

                // 变更文件列表
                changedFilesSection
            }
            .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .padding(.vertical, 12)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
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
                        .font(.system(size: 14, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 10)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                        .padding(.bottom, 40)  // 这是底部内边距，控制内容下方与边缘的空白距离，单位是pt；改大下方留白更宽，改小下方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边
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
                .font(.system(size: 18, weight: .bold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
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
                .frame(width: 40, height: 40)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(commit.authorName)
                        .font(.system(size: 15, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .white : .primary)
                    Text("提交于 \(commit.formattedDate)")
                        .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 提交哈希
                VStack(alignment: .trailing, spacing: 4) {
                    Text("提交哈希")
                        .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                    Button(action: {
                        UIPasteboard.general.string = commit.sha
                        operationMessage = "已复制完整提交哈希"
                        showOperationMessage = true
                    }) {
                        HStack(spacing: 4) {
                            Text(commit.shortSha)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 完整哈希
            HStack {
                Text(commit.sha)
                    .font(.system(size: 12, design: .monospaced))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
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
                        .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
            .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
            .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
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
        .padding(.vertical, 12)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
    }

    // MARK: - 统计项
    private func statItem(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(appState.isDarkMode ? .white : .primary)
            Text(title)
                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 变更文件列表
    private var changedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("变更文件")
                    .font(.system(size: 16, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                Text("(\(changedFiles.count))")
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
                Spacer()
            }

            if isLoadingFiles {
                HStack {
                    Spacer()
                    ProgressView("加载变更文件...")
                    Spacer()
                }
                .padding(.vertical, 40)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            } else if let error = filesError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        loadChangedFiles()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 40)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .frame(maxWidth: .infinity)
            } else if changedFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                    Text("暂无变更文件")
                        .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .frame(maxWidth: .infinity)
            } else {
                ForEach(changedFiles) { file in
                    ChangedFileRow(file: file)
                        .onTapGesture {
                            selectedFile = file
                        }

                    if file.id != changedFiles.last?.id {
                        Divider()
                            .padding(.leading, 32)  // 这是左侧内边距，控制内容左方与边缘的空白距离，单位是pt；改大左方留白更宽，改小左方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
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
                .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(statusColor)
                .frame(width: 20)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            // 文件名
            VStack(alignment: .leading, spacing: 2) {
                Text(fileNameOnly)
                    .font(.system(size: 14, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .lineLimit(1)

                // 文件路径
                if !filePath.isEmpty {
                    Text(filePath)
                        .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 变更统计
            HStack(spacing: 8) {
                if file.additions > 0 {
                    Text("+\(file.additions)")
                        .font(.system(size: 12, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.green)
                }

                if file.deletions > 0 {
                    Text("-\(file.deletions)")
                        .font(.system(size: 12, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.red)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
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
                            .font(.system(size: 14, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(appState.isDarkMode ? .white : .primary)
                            .lineLimit(1)
                        Spacer()
                        // 变更统计
                        HStack(spacing: 6) {
                            if file.additions > 0 {
                                Text("+\(file.additions)")
                                    .font(.system(size: 12, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                    .foregroundColor(.green)
                            }
                            if file.deletions > 0 {
                                Text("-\(file.deletions)")
                                    .font(.system(size: 12, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
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
                                .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.secondary)
                            Text("此文件为二进制文件或无可用的Diff内容")
                                .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
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
                        .font(.system(size: 11, design: .monospaced))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                        .padding(.trailing, 8)  // 这是右侧内边距，控制内容右方与边缘的空白距离，单位是pt；改大右方留白更宽，改小右方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边

                    // 行内容
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(lineColor(line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 1)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(lineBackground(line))
            }
        }
        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
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
