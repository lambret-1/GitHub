import SwiftUI

// MARK: - 提交变更文件Diff查看器

struct DiffView: View {
    let owner: String
    let repo: String
    let changedFile: ChangedFile

    @State private var diffContent: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showEditor: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 文件信息头部
            fileInfoHeader

            // Diff内容
            diffContentSection
        }
        .navigationTitle(changedFile.shortFilename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showEditor = true
                }) {
                    Image(systemName: "pencil")
                }
            }
        }
        .background(
            NavigationLink(destination: editorDestination, isActive: $showEditor) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            loadDiff()
        }
    }

    // MARK: - 编辑器目标视图

    @ViewBuilder
    private var editorDestination: some View {
        FileEditorView(owner: owner, repo: repo, filePath: changedFile.filename, branch: changedFile.sha)
    }

    // MARK: - 文件信息头部

    private var fileInfoHeader: some View {
        HStack {
            Image(systemName: changedFile.statusIcon)
                .foregroundColor(changedFile.statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(changedFile.filename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(changedFile.statusDisplay)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(changedFile.statusColor)
                    Text("+\(changedFile.additions)")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("-\(changedFile.deletions)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Diff内容区域

    private var diffContentSection: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载Diff中...")
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
                        loadDiff()
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }
                .padding()
            } else if diffContent.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无Diff内容")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // Diff内容显示
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diffContent.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                            diffLineView(line: line, lineNumber: index + 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Diff行视图

    private func diffLineView(line: String, lineNumber: Int) -> some View {
        let backgroundColor: Color
        let textColor: Color
        let prefix: String

        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            backgroundColor = Color.green.opacity(0.1)
            textColor = .green
            prefix = "+"
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            backgroundColor = Color.red.opacity(0.1)
            textColor = .red
            prefix = "-"
        } else if line.hasPrefix("@@") {
            backgroundColor = Color.blue.opacity(0.1)
            textColor = .blue
            prefix = ""
        } else if line.hasPrefix("diff") || line.hasPrefix("index") || line.hasPrefix("---") || line.hasPrefix("+++") {
            backgroundColor = Color.gray.opacity(0.1)
            textColor = .gray
            prefix = ""
        } else {
            backgroundColor = Color(.systemBackground)
            textColor = .primary
            prefix = " "
        }

        return HStack(alignment: .top, spacing: 0) {
            // 行号
            Text("\(lineNumber)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 35, alignment: .trailing)
                .padding(.trailing, 6)
            // 前缀符号
            Text(prefix)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 10)
            // Diff内容
            Text(line)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 0.5)
        .background(backgroundColor)
    }

    // MARK: - 加载Diff内容

    private func loadDiff() {
        isLoading = true
        errorMessage = nil

        // 如果ChangedFile有patch字段，直接使用
        if let patch = changedFile.patch, !patch.isEmpty {
            diffContent = patch
            isLoading = false
            return
        }

        // 否则通过API获取文件内容
        guard let contentsUrl = changedFile.contentsUrl, let url = URL(string: contentsUrl) else {
            errorMessage = "无法获取Diff内容"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3.diff", forHTTPHeaderField: "Accept")
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "加载Diff失败: \(error.localizedDescription)"
                    return
                }

                if let data = data, let content = String(data: data, encoding: .utf8) {
                    diffContent = content
                } else {
                    errorMessage = "无法解析Diff内容"
                }
            }
        }
        task.resume()
    }
}
