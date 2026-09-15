import SwiftUI

struct RepoCodeSearchView: View {
    @StateObject private var viewModel: RepoCodeSearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var debounceTask: Task<Void, Never>?
    @State private var showSortMenu: Bool = false
    @FocusState private var isSearchFieldFocused: Bool // 搜索输入框聚焦状态，控制光标显示和键盘弹出
    private let onJumpToCode: (String, Int) -> Void

    init(owner: String, repo: String, branch: String, onJumpToCode: @escaping (String, Int) -> Void) {
        _viewModel = StateObject(wrappedValue: RepoCodeSearchViewModel(owner: owner, repo: repo, branch: branch))
        self.onJumpToCode = onJumpToCode
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                if viewModel.showSuggestions && !viewModel.searchSuggestions.isEmpty {
                    suggestionsList
                }
                content
            }
            .navigationTitle("仓库内搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("排序方式", selection: $viewModel.sortOption) {
                            ForEach(CodeSearchSortOption.allCases) { option in
                                Label(option.rawValue, systemImage: sortIcon(for: option))
                                    .tag(option)
                            }
                        }
                        .onChange(of: viewModel.sortOption) { _ in
                            viewModel.changeSortOption(viewModel.sortOption)
                        }

                        Divider()

                        Button {
                            viewModel.refresh()
                        } label: {
                            Label("刷新搜索（清除缓存）", systemImage: "arrow.clockwise")
                        }

                        if !viewModel.searchHistory.isEmpty {
                            Divider()
                            Button(role: .destructive) {
                                viewModel.clearAllHistory()
                            } label: {
                                Label("清除搜索历史", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $viewModel.selectedFile) { file in
                CodeSnippetSheet(
                    file: file,
                    viewModel: viewModel,
                    query: viewModel.query,
                    onJump: { line in
                        onJumpToCode(file.path, line)
                        dismiss()
                    }
                )
            }
            .onAppear {
                // 打开搜索页面时自动聚焦输入框并弹出键盘，提升用户体验
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
            .onDisappear { viewModel.cancel() }
        }
    }

    // 排序选项图标
    private func sortIcon(for option: CodeSearchSortOption) -> String {
        switch option {
        case .updated: return "clock"
        case .path: return "folder"
        case .relevance: return "star"
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
                .focused($isSearchFieldFocused) // 绑定聚焦状态，控制光标显示和键盘弹出
                .onSubmit {
                    viewModel.showSuggestions = false
                    viewModel.search()
                }
                .onChange(of: viewModel.query) { _ in
                    viewModel.updateSuggestions()
                    viewModel.showSuggestions = true
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled {
                            viewModel.showSuggestions = false
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

    // 搜索建议列表
    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.searchSuggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.selectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text(suggestion)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            if viewModel.searchHistory.isEmpty {
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
            } else {
                List {
                    Section {
                        HStack {
                            Text("搜索历史")
                                .font(.headline)
                            Spacer()
                            Button("清除") {
                                viewModel.clearAllHistory()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                    ForEach(viewModel.searchHistory) { item in
                        HStack {
                            Button {
                                viewModel.selectHistory(item)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.gray)
                                        .frame(width: 20)
                                    Text(item.query)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            Button {
                                viewModel.removeHistory(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
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
                    HStack {
                        Text("共找到 \(viewModel.results.count) 个文件包含匹配")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Menu {
                            Picker("排序", selection: $viewModel.sortOption) {
                                ForEach(CodeSearchSortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .onChange(of: viewModel.sortOption) { _ in
                                viewModel.changeSortOption(viewModel.sortOption)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.sortOption.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
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
                                HStack(spacing: 6) {
                                    Text(file.path)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("·")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    // 最后编辑时间：xx分钟/小时/日/月/年之前
                                    HStack(spacing: 2) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text(file.lastModifiedRelativeString)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
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
            .refreshable {
                viewModel.refresh()
            }
        }
    }
}

private struct CodeSnippetSheet: View {
    let file: CodeSearchFile
    let viewModel: RepoCodeSearchViewModel
    let query: String
    let onJump: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
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
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return attr }
        if let range = text.range(of: trimmedQuery, options: .caseInsensitive) {
            if let attrRange = Range(range, in: attr) {
                attr[attrRange].backgroundColor = .yellow
                attr[attrRange].foregroundColor = .red
                attr[attrRange].font = .system(size: 12, weight: .bold, design: .monospaced)
            }
        }
        return attr
    }
}
