import SwiftUI

struct RepoCodeSearchView: View {
    @StateObject private var viewModel: RepoCodeSearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var debounceTask: Task<Void, Never>?
    private let onJumpToCode: (String, Int) -> Void

    init(owner: String, repo: String, branch: String, onJumpToCode: @escaping (String, Int) -> Void) {
        _viewModel = StateObject(wrappedValue: RepoCodeSearchViewModel(owner: owner, repo: repo, branch: branch))
        self.onJumpToCode = onJumpToCode
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                content
            }
            .navigationTitle("仓库内搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(item: $viewModel.selectedFile) { file in
                CodeSnippetSheet(
                    file: file,
                    viewModel: viewModel,
                    onJump: { line in
                        onJumpToCode(file.path, line)
                        dismiss()
                    }
                )
            }
            .onDisappear { viewModel.cancel() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("输入搜索词，如 func、import、类名", text: $viewModel.query)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { viewModel.search() }
                .onChange(of: viewModel.query) { _ in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled {
                            viewModel.search()
                        }
                    }
                }
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("在仓库内搜索代码")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text("支持搜索函数名、类名、变量名等")
                    .font(.subheadline)
                    .foregroundColor(.gray.opacity(0.8))
            }
            Spacer()
        case .searching:
            Spacer()
            ProgressView("搜索中...")
            Spacer()
        case .empty:
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("未找到匹配结果")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            Spacer()
        case .error(let msg):
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(msg)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("重试") { viewModel.search() }
                    .buttonStyle(.bordered)
            }
            Spacer()
        case .success:
            List {
                Section {
                    Text("共找到 \(viewModel.results.count) 个文件包含匹配")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                ForEach(viewModel.results) { file in
                    Button {
                        viewModel.loadSnippets(for: file)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(file.path)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct CodeSnippetSheet: View {
    let file: CodeSearchFile
    let viewModel: RepoCodeSearchViewModel
    let onJump: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if viewModel.snippetLoading {
                    Spacer()
                    ProgressView("加载代码片段...")
                    Spacer()
                } else if viewModel.snippets.isEmpty {
                    Spacer()
                    Text("未找到匹配的代码行")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(viewModel.snippets.enumerated()), id: \.element.id) { idx, snippet in
                                if idx > 0 {
                                    Divider()
                                        .padding(.vertical, 8)
                                }
                                snippetView(snippet)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            Text(file.path)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private func snippetView(_ snippet: CodeSnippet) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("第 \(snippet.startLine) - \(snippet.endLine) 行")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.bottom, 4)
            ForEach(snippet.lines) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(line.lineNumber)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 36, alignment: .trailing)
                    Text(highlightedText(line.content))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(line.isMatch ? .black : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 1)
                .background(line.isMatch ? Color.yellow.opacity(0.3) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    onJump(line.lineNumber)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func highlightedText(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        let query = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return attr }
        if let range = text.range(of: query, options: .caseInsensitive) {
            if let attrRange = Range(range, in: attr) {
                attr[attrRange].backgroundColor = .yellow
                attr[attrRange].foregroundColor = .red
                attr[attrRange].font = .system(size: 12, weight: .bold, design: .monospaced)
            }
        }
        return attr
    }
}
