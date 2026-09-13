import SwiftUI

// MARK: - 工作流文件查看器

struct WorkflowFileView: View {
    let owner: String
    let repo: String
    let workflow: Workflow
    @State private var fileContent: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showCopySuccess: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 文件信息头部
            fileInfoHeader

            // 内容区域
            contentSection
        }
        .navigationTitle(workflow.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            HStack(spacing: 16) {
                Button(action: {
                    copyContent()
                }) {
                    Image(systemName: "doc.on.doc")
                }
                Button(action: {
                    loadFileContent()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        )
        .onAppear {
            loadFileContent()
        }
        .overlay(
            // 复制成功提示
            Group {
                if showCopySuccess {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("已复制到剪贴板")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.bottom, 40)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        )
    }

    // MARK: - 文件信息头部

    private var fileInfoHeader: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("状态: \(workflow.state == "active" ? "启用" : "禁用")")
                    .font(.caption2)
                    .foregroundColor(workflow.state == "active" ? .green : .gray)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - 内容区域

    private var contentSection: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载工作流文件中...")
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
                    .foregroundColor(.blue)
                    Spacer()
                }
                .padding()
            } else if fileContent.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("文件内容为空")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // YAML内容显示
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(fileContent.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                                HStack(alignment: .top, spacing: 0) {
                                    // 行号
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                        .frame(width: 40, alignment: .trailing)
                                        .padding(.trailing, 8)
                                    // 代码内容
                                    Text(line)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(colorForLine(line))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(index % 2 == 0 ? Color(.systemBackground) : Color(.systemGray6).opacity(0.3))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - YAML语法高亮

    private func colorForLine(_ line: String) -> Color {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // 注释
        if trimmed.hasPrefix("#") {
            return .gray
        }
        // 键值对（key: value）
        if trimmed.contains(":") && !trimmed.hasPrefix("-") {
            return .blue
        }
        // 列表项
        if trimmed.hasPrefix("-") {
            return .green
        }
        // 字符串值
        if trimmed.hasPrefix("\"") || trimmed.hasPrefix("'") {
            return .orange
        }
        return .primary
    }

    // MARK: - 数据加载

    private func loadFileContent() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getFileContent(owner: owner, repo: repo, path: workflow.path) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fileContent):
                    if let content = fileContent.decodedContent {
                        self.fileContent = content
                    } else {
                        self.errorMessage = "无法解码文件内容"
                    }
                case .failure(let error):
                    self.errorMessage = "加载失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 复制内容

    private func copyContent() {
        UIPasteboard.general.string = fileContent
        withAnimation {
            showCopySuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopySuccess = false
            }
        }
    }
}
