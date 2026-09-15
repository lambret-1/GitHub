import SwiftUI

// MARK: - Issues列表视图
struct IssuesListView: View {
    let owner: String
    let repo: String
    @EnvironmentObject var appState: AppState

    // Issues列表状态
    @State private var issues: [Issue] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedState: String = "open" // open / closed / all
    @State private var currentPage: Int = 1
    @State private var hasMore: Bool = true
    @State private var isLoadingMore: Bool = false

    // 创建Issue弹窗
    @State private var showCreateIssue: Bool = false
    @State private var newIssueTitle: String = ""
    @State private var newIssueBody: String = ""
    @State private var isCreating: Bool = false

    // 选中的Issue（用于跳转详情）
    @State private var selectedIssue: Issue?

    var body: some View {
        VStack(spacing: 0) {
            // 状态切换栏 + 新建按钮
            HStack(spacing: 12) {
                stateSegmentControl
                    .frame(maxWidth: .infinity)

                Button(action: { showCreateIssue = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧

            // Issues列表
            if isLoading && issues.isEmpty {
                loadingView
            } else if let error = errorMessage, issues.isEmpty {
                errorView(error: error)
            } else if issues.isEmpty {
                emptyView
            } else {
                issuesList
            }
        }
        .sheet(isPresented: $showCreateIssue) {
            createIssueSheet
        }
        .sheet(item: $selectedIssue) { issue in
            IssueDetailView(owner: owner, repo: repo, issue: issue)
        }
        .onAppear {
            if issues.isEmpty {
                loadIssues()
            }
        }
        .refreshable {
            currentPage = 1
            hasMore = true
            loadIssues()
        }
    }

    // MARK: - 状态切换栏
    private var stateSegmentControl: some View {
        Picker("状态", selection: $selectedState) {
            Text("开放").tag("open")
            Text("已关闭").tag("closed")
            Text("全部").tag("all")
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedState) { _ in
            currentPage = 1
            hasMore = true
            issues.removeAll()
            loadIssues()
        }
    }

    // MARK: - Issues列表
    private var issuesList: some View {
        List {
            ForEach(issues) { issue in
                IssueRow(issue: issue)
                    .onTapGesture {
                        selectedIssue = issue
                    }
                    .onAppear {
                        // 滚动到底部时加载更多
                        if issue.id == issues.last?.id && hasMore && !isLoadingMore {
                            loadMoreIssues()
                        }
                    }
                    .listRowBackground(appState.isDarkMode ? Color.black : Color.white)
            }

            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .background(appState.isDarkMode ? Color.black : Color(.systemBackground))
    }

    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 错误视图
    private func errorView(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                currentPage = 1
                hasMore = true
                loadIssues()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空视图
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
            Text(selectedState == "open" ? "暂无开放的Issue" : "暂无已关闭的Issue")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 创建Issue弹窗
    private var createIssueSheet: some View {
        NavigationView {
            Form {
                Section("标题") {
                    TextField("请输入Issue标题", text: $newIssueTitle)
                }
                Section("描述（可选）") {
                    TextEditor(text: $newIssueBody)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("新建Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCreateIssue = false
                        newIssueTitle = ""
                        newIssueBody = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createIssue()
                    }
                    .disabled(newIssueTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ProgressView("创建中...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
            }
        }
    }

    // MARK: - 加载Issues
    private func loadIssues() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getIssues(owner: owner, repo: repo, state: selectedState, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let newIssues):
                    issues = newIssues
                    hasMore = newIssues.count >= 30
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 加载更多Issues
    private func loadMoreIssues() {
        isLoadingMore = true
        currentPage += 1

        GitHubAPI.shared.getIssues(owner: owner, repo: repo, state: selectedState, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoadingMore = false
                switch result {
                case .success(let newIssues):
                    issues.append(contentsOf: newIssues)
                    hasMore = newIssues.count >= 30
                case .failure:
                    currentPage -= 1
                }
            }
        }
    }

    // MARK: - 创建Issue
    private func createIssue() {
        isCreating = true
        let title = newIssueTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = newIssueBody.trimmingCharacters(in: .whitespacesAndNewlines)

        GitHubAPI.shared.createIssue(owner: owner, repo: repo, title: title, body: body.isEmpty ? nil : body) { result in
            DispatchQueue.main.async {
                isCreating = false
                switch result {
                case .success:
                    showCreateIssue = false
                    newIssueTitle = ""
                    newIssueBody = ""
                    // 刷新列表
                    currentPage = 1
                    hasMore = true
                    loadIssues()
                case .failure(let error):
                    errorMessage = "创建失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Issue行视图
struct IssueRow: View {
    let issue: Issue
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 状态图标
            Image(systemName: issue.state.图标名称)
                .foregroundColor(issue.state.颜色)
                .font(.system(size: 18))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .padding(.top, 2)  // 这是顶部内边距，控制内容上方与边缘的空白距离，单位是pt；改大上方留白更宽，改小上方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边

            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(issue.title)
                    .font(.system(size: 15, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .lineLimit(2)

                // 标签
                if let labels = issue.labels, !labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(labels.prefix(3)) { label in
                            Text(label.name)
                                .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .padding(.horizontal, 6)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                                .padding(.vertical, 2)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                                .background(label.背景颜色)
                                .foregroundColor(label.文字颜色)
                                .cornerRadius(4)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                        }
                        if labels.count > 3 {
                            Text("+\(labels.count - 3)")
                                .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 底部信息
                HStack(spacing: 8) {
                    Text("#\(issue.number)")
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)

                    Text(issue.user.login)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)

                    Text(issue.创建时间显示)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)

                    if issue.comments > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            Text("\(issue.comments)")
                                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .contentShape(Rectangle())
    }
}
