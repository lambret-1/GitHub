import SwiftUI

// MARK: - PR列表视图
struct PullRequestsListView: View {
    let owner: String
    let repo: String
    @EnvironmentObject var appState: AppState

    // PR列表状态
    @State private var pullRequests: [PullRequest] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedState: String = "open" // open / closed / all
    @State private var currentPage: Int = 1
    @State private var hasMore: Bool = true
    @State private var isLoadingMore: Bool = false

    // 创建PR弹窗
    @State private var showCreatePR: Bool = false
    @State private var newPRTitle: String = ""
    @State private var newPRHead: String = ""
    @State private var newPRBase: String = "main"
    @State private var newPRBody: String = ""
    @State private var isCreating: Bool = false

    // 选中的PR（用于跳转详情）
    @State private var selectedPR: PullRequest?

    var body: some View {
        VStack(spacing: 0) {
            // 状态切换栏 + 新建按钮
            HStack(spacing: 12) {
                stateSegmentControl
                    .frame(maxWidth: .infinity)

                Button(action: { showCreatePR = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧

            // PR列表
            if isLoading && pullRequests.isEmpty {
                loadingView
            } else if let error = errorMessage, pullRequests.isEmpty {
                errorView(error: error)
            } else if pullRequests.isEmpty {
                emptyView
            } else {
                prList
            }
        }
        .sheet(isPresented: $showCreatePR) {
            createPRSheet
        }
        .sheet(item: $selectedPR) { pr in
            PullRequestDetailView(owner: owner, repo: repo, pullRequest: pr)
        }
        .onAppear {
            if pullRequests.isEmpty {
                loadPullRequests()
            }
        }
        .ios14Refreshable {
            currentPage = 1
            hasMore = true
            loadPullRequests()
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
            pullRequests.removeAll()
            loadPullRequests()
        }
    }

    // MARK: - PR列表
    private var prList: some View {
        List {
            ForEach(pullRequests) { pr in
                PullRequestRow(pr: pr)
                    .onTapGesture {
                        selectedPR = pr
                    }
                    .onAppear {
                        // 滚动到底部时加载更多
                        if pr.id == pullRequests.last?.id && hasMore && !isLoadingMore {
                            loadMorePullRequests()
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
                loadPullRequests()
            }
            
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空视图
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
            Text(selectedState == "open" ? "暂无开放的Pull Request" : "暂无已关闭的Pull Request")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 创建PR弹窗
    private var createPRSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("标题")) { // iOS14兼容：使用旧版Section语法
                    TextField("请输入PR标题", text: $newPRTitle)
                }
                Section(header: Text("源分支（head）")) { // iOS14兼容：使用旧版Section语法
                    TextField("例如：feature/new-feature", text: $newPRHead)
                }
                Section(header: Text("目标分支（base）")) { // iOS14兼容：使用旧版Section语法
                    TextField("例如：main", text: $newPRBase)
                }
                Section(header: Text("描述（可选）")) { // iOS14兼容：使用旧版Section语法
                    TextEditor(text: $newPRBody)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("新建Pull Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCreatePR = false
                        newPRTitle = ""
                        newPRHead = ""
                        newPRBase = "main"
                        newPRBody = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createPullRequest()
                    }
                    .disabled(newPRTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newPRHead.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newPRBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              isCreating)
                }
            }
            .overlay( // iOS14兼容：使用旧版overlay语法
                Group {
                    if isCreating {
                        ProgressView("创建中...")
                            .padding()
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    }
                },
                alignment: .center
            )
        }
    }

    // MARK: - 加载PR列表
    private func loadPullRequests() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getPullRequests(owner: owner, repo: repo, state: selectedState, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let newPRs):
                    pullRequests = newPRs
                    hasMore = newPRs.count >= 30
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 加载更多PR
    private func loadMorePullRequests() {
        isLoadingMore = true
        currentPage += 1

        GitHubAPI.shared.getPullRequests(owner: owner, repo: repo, state: selectedState, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoadingMore = false
                switch result {
                case .success(let newPRs):
                    pullRequests.append(contentsOf: newPRs)
                    hasMore = newPRs.count >= 30
                case .failure:
                    currentPage -= 1
                }
            }
        }
    }

    // MARK: - 创建PR
    private func createPullRequest() {
        isCreating = true
        let title = newPRTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = newPRHead.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = newPRBase.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = newPRBody.trimmingCharacters(in: .whitespacesAndNewlines)

        GitHubAPI.shared.createPullRequest(owner: owner, repo: repo, title: title, head: head, base: base, body: body.isEmpty ? nil : body) { result in
            DispatchQueue.main.async {
                isCreating = false
                switch result {
                case .success:
                    showCreatePR = false
                    newPRTitle = ""
                    newPRHead = ""
                    newPRBase = "main"
                    newPRBody = ""
                    // 刷新列表
                    currentPage = 1
                    hasMore = true
                    loadPullRequests()
                case .failure(let error):
                    errorMessage = "创建失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - PR行视图
struct PullRequestRow: View {
    let pr: PullRequest
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 状态图标
            Image(systemName: pr.state.图标名称)
                .foregroundColor(pr.state.颜色)
                .font(.system(size: 18))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .padding(.top, 2)  // 这是顶部内边距，控制内容上方与边缘的空白距离，单位是pt；改大上方留白更宽，改小上方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边

            VStack(alignment: .leading, spacing: 4) {
                // 标题
                HStack(spacing: 6) {
                    Text(pr.title)
                        .font(.system(size: 15, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .white : .primary)
                        .lineLimit(2)

                    if pr.是草稿 {
                        Text("草稿")
                            .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .padding(.horizontal, 4)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                            .padding(.vertical, 1)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    }
                }

                // 标签
                if let labels = pr.labels, !labels.isEmpty {
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

                // 分支信息
                HStack(spacing: 4) {
                    Text(pr.head.分支名称)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                    Text(pr.base.分支名称)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                }

                // 底部信息
                HStack(spacing: 8) {
                    Text("#\(pr.number)")
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)

                    Text(pr.user.login)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)

                    Text(pr.创建时间显示)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)

                    if let comments = pr.comments, comments > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            Text("\(comments)")
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
