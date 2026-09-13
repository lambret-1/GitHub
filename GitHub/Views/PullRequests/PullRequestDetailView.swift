import SwiftUI

// MARK: - PR详情视图
struct PullRequestDetailView: View {
    let owner: String
    let repo: String
    @State var pullRequest: PullRequest
    @EnvironmentObject var appState: AppState

    // Tab切换
    enum PRTab: String, CaseIterable {
        case conversation = "对话"
        case commits = "提交"
        case files = "文件变更"
    }
    @State private var selectedTab: PRTab = .conversation

    // 评论列表状态
    @State private var comments: [PullRequestComment] = []
    @State private var isLoadingComments: Bool = false
    @State private var commentsError: String?

    // 审查列表状态
    @State private var reviews: [PullRequestReview] = []
    @State private var isLoadingReviews: Bool = false

    // 提交列表状态
    @State private var commits: [PullRequestCommit] = []
    @State private var isLoadingCommits: Bool = false

    // 变更文件列表状态
    @State private var files: [PullRequestFile] = []
    @State private var isLoadingFiles: Bool = false

    // 添加评论
    @State private var newComment: String = ""
    @State private var isAddingComment: Bool = false

    // 合并/关闭
    @State private var isUpdatingState: Bool = false
    @State private var showMergeConfirm: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // PR头部信息
                prHeader

                // 分支信息和变更统计
                branchInfo

                // Tab切换
                prTabBar

                // Tab内容
                switch selectedTab {
                case .conversation:
                    conversationContent
                case .commits:
                    commitsContent
                case .files:
                    filesContent
                }
            }
            .padding()
        }
        .navigationTitle("#\(pullRequest.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if pullRequest.state == .open {
                        Button(role: .destructive) {
                            closePR()
                        } label: {
                            Label("关闭PR", systemImage: "xmark.circle")
                        }
                    } else if pullRequest.state == .closed {
                        Button {
                            reopenPR()
                        } label: {
                            Label("重新打开", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadAllData()
        }
        .alert("确认合并", isPresented: $showMergeConfirm) {
            Button("取消", role: .cancel) {}
            Button("合并") {
                mergePR()
            }
        } message: {
            Text("确定要合并这个Pull Request吗？此操作不可撤销。")
        }
        .overlay {
            if isUpdatingState {
                ProgressView("处理中...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - PR头部信息
    private var prHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(pullRequest.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(appState.isDarkMode ? .white : .primary)

            // 状态和元信息
            HStack(spacing: 12) {
                // 状态标签
                HStack(spacing: 4) {
                    Image(systemName: pullRequest.state.图标名称)
                    Text(pullRequest.state.显示文本)
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(pullRequest.state.颜色.opacity(0.15))
                .foregroundColor(pullRequest.state.颜色)
                .cornerRadius(12)

                Text("#\(pullRequest.number)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text("由 \(pullRequest.user.login) 创建于 \(pullRequest.创建时间显示)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // 标签
            if let labels = pullRequest.labels, !labels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(labels) { label in
                        Text(label.name)
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(label.背景颜色)
                            .foregroundColor(label.文字颜色)
                            .cornerRadius(4)
                    }
                }
            }

            // 里程碑
            if let milestone = pullRequest.milestone {
                HStack(spacing: 4) {
                    Image(systemName: "milestone")
                        .font(.system(size: 12))
                    Text(milestone.title)
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 分支信息和变更统计
    private var branchInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 分支信息
            HStack(spacing: 8) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("源分支")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(pullRequest.head.完整标签)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("目标分支")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(pullRequest.base.完整标签)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
            .cornerRadius(8)

            // 变更统计
            HStack(spacing: 16) {
                if let commits = pullRequest.commits {
                    VStack(spacing: 2) {
                        Text("\(commits)")
                            .font(.system(size: 16, weight: .bold))
                        Text("提交")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if let changedFiles = pullRequest.changedFiles {
                    VStack(spacing: 2) {
                        Text("\(changedFiles)")
                            .font(.system(size: 16, weight: .bold))
                        Text("文件变更")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if let additions = pullRequest.additions {
                    VStack(spacing: 2) {
                        Text("+\(additions)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                        Text("新增")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if let deletions = pullRequest.deletions {
                    VStack(spacing: 2) {
                        Text("-\(deletions)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                        Text("删除")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 合并状态
                if pullRequest.state == .open {
                    if let mergeableState = pullRequest.mergeableState {
                        HStack(spacing: 4) {
                            Image(systemName: mergeableState == .clean ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(mergeableState == .clean ? .green : .orange)
                            Text(mergeableState.显示文本)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - PR Tab栏
    private var prTabBar: some View {
        HStack(spacing: 0) {
            ForEach(PRTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .blue : .secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(appState.isDarkMode ? Color.black : Color.white)
    }

    // MARK: - 对话内容
    private var conversationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // PR描述
            if let body = pullRequest.body, !body.isEmpty {
                prBody(body)
            }

            // 审查列表
            if !reviews.isEmpty {
                reviewsSection
            }

            // 评论列表
            commentsSection

            // 添加评论
            addCommentSection

            // 合并按钮
            if pullRequest.state == .open {
                mergeButton
            }
        }
    }

    // MARK: - PR描述
    private func prBody(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 用户信息
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: pullRequest.user.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())

                Text(pullRequest.user.login)
                    .font(.system(size: 14, weight: .semibold))

                Text(pullRequest.创建时间显示)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 描述内容
            Text(body)
                .font(.system(size: 14))
                .foregroundColor(appState.isDarkMode ? .white.opacity(0.9) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    // MARK: - 审查列表
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("审查 (\(reviews.count))")
                .font(.system(size: 16, weight: .semibold))

            ForEach(reviews) { review in
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: review.user.avatarUrl ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                    Text(review.user.login)
                        .font(.system(size: 13, weight: .medium))

                    Text(review.状态显示)
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(review.状态颜色.opacity(0.15))
                        .foregroundColor(review.状态颜色)
                        .cornerRadius(4)

                    Text(review.提交时间显示)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()
                }

                if let body = review.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundColor(appState.isDarkMode ? .white.opacity(0.8) : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(appState.isDarkMode ? Color.white.opacity(0.03) : Color(.systemGray6))
                        .cornerRadius(6)
                        .padding(.leading, 32)
                }
            }
        }
    }

    // MARK: - 评论列表
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if comments.isEmpty && !isLoadingComments && commentsError == nil {
                EmptyView()
            } else {
                Divider()

                Text("评论 (\(comments.count))")
                    .font(.system(size: 16, weight: .semibold))

                if isLoadingComments {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if let error = commentsError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                } else {
                    ForEach(comments) { comment in
                        commentRow(comment)
                    }
                }
            }
        }
    }

    // MARK: - 评论行
    private func commentRow(_ comment: PullRequestComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 用户信息
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: comment.user.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())

                Text(comment.user.login)
                    .font(.system(size: 14, weight: .semibold))

                Text(comment.创建时间显示)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 评论内容
            if let body = comment.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14))
                    .foregroundColor(appState.isDarkMode ? .white.opacity(0.9) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - 添加评论
    private var addCommentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("添加评论")
                .font(.system(size: 16, weight: .semibold))

            TextEditor(text: $newComment)
                .font(.system(size: 14))
                .frame(minHeight: 80)
                .padding(8)
                .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                .cornerRadius(8)

            HStack {
                Spacer()
                Button(action: { addComment() }) {
                    if isAddingComment {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("发表评论")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingComment)
            }
        }
    }

    // MARK: - 合并按钮
    private var mergeButton: some View {
        VStack(spacing: 8) {
            Divider()

            Button(action: {
                showMergeConfirm = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.merge")
                    Text("合并 Pull Request")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(8)
            }
            .disabled(pullRequest.mergeableState != .clean)
        }
    }

    // MARK: - 提交内容
    private var commitsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoadingCommits {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if commits.isEmpty {
                Text("暂无提交")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(commits) { commit in
                    HStack(alignment: .top, spacing: 10) {
                        // 提交图标
                        Image(systemName: "commit")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            // 提交信息
                            Text(commit.commit.message ?? "无提交信息")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(appState.isDarkMode ? .white : .primary)
                                .lineLimit(2)

                            // 作者和哈希
                            HStack(spacing: 8) {
                                Text(commit.commit.author?.name ?? "未知")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)

                                Text(commit.短哈希)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if commit.id != commits.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - 文件变更内容
    private var filesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoadingFiles {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if files.isEmpty {
                Text("暂无文件变更")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(files) { file in
                    VStack(alignment: .leading, spacing: 6) {
                        // 文件名和状态
                        HStack(spacing: 8) {
                            Image(systemName: file.status == "removed" ? "trash" : "doc")
                                .font(.system(size: 14))
                                .foregroundColor(file.状态颜色)

                            Text(file.filename)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(appState.isDarkMode ? .white : .primary)
                                .lineLimit(1)

                            Spacer()

                            Text(file.状态显示)
                                .font(.system(size: 11))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(file.状态颜色.opacity(0.15))
                                .foregroundColor(file.状态颜色)
                                .cornerRadius(4)
                        }

                        // 变更统计
                        HStack(spacing: 12) {
                            Text("+\(file.additions)")
                                .font(.system(size: 12))
                                .foregroundColor(.green)

                            Text("-\(file.deletions)")
                                .font(.system(size: 12))
                                .foregroundColor(.red)

                            Text("\(file.changes) 处变更")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                    }
                    .padding(.vertical, 6)

                    if file.id != files.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - 加载所有数据
    private func loadAllData() {
        loadComments()
        loadReviews()
        loadCommits()
        loadFiles()
    }

    // MARK: - 加载评论
    private func loadComments() {
        isLoadingComments = true
        commentsError = nil

        GitHubAPI.shared.getPullRequestComments(owner: owner, repo: repo, number: pullRequest.number) { result in
            DispatchQueue.main.async {
                isLoadingComments = false
                switch result {
                case .success(let commentList):
                    comments = commentList
                case .failure(let error):
                    commentsError = "加载评论失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 加载审查
    private func loadReviews() {
        isLoadingReviews = true

        GitHubAPI.shared.getPullRequestReviews(owner: owner, repo: repo, number: pullRequest.number) { result in
            DispatchQueue.main.async {
                isLoadingReviews = false
                switch result {
                case .success(let reviewList):
                    reviews = reviewList
                case .failure:
                    reviews = []
                }
            }
        }
    }

    // MARK: - 加载提交
    private func loadCommits() {
        isLoadingCommits = true

        GitHubAPI.shared.getPullRequestCommits(owner: owner, repo: repo, number: pullRequest.number) { result in
            DispatchQueue.main.async {
                isLoadingCommits = false
                switch result {
                case .success(let commitList):
                    commits = commitList
                case .failure:
                    commits = []
                }
            }
        }
    }

    // MARK: - 加载变更文件
    private func loadFiles() {
        isLoadingFiles = true

        GitHubAPI.shared.getPullRequestFiles(owner: owner, repo: repo, number: pullRequest.number) { result in
            DispatchQueue.main.async {
                isLoadingFiles = false
                switch result {
                case .success(let fileList):
                    files = fileList
                case .failure:
                    files = []
                }
            }
        }
    }

    // MARK: - 添加评论
    private func addComment() {
        isAddingComment = true
        let body = newComment.trimmingCharacters(in: .whitespacesAndNewlines)

        GitHubAPI.shared.createIssueComment(owner: owner, repo: repo, number: pullRequest.number, body: body) { result in
            DispatchQueue.main.async {
                isAddingComment = false
                switch result {
                case .success(let comment):
                    comments.append(comment)
                    newComment = ""
                case .failure(let error):
                    commentsError = "发表评论失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 合并PR
    private func mergePR() {
        isUpdatingState = true
        // 使用PR的head sha作为合并sha
        let sha = pullRequest.head.sha

        GitHubAPI.shared.mergePullRequest(owner: owner, repo: repo, number: pullRequest.number, sha: sha) { result in
            DispatchQueue.main.async {
                isUpdatingState = false
                switch result {
                case .success:
                    // 重新加载PR详情
                    GitHubAPI.shared.getPullRequestDetail(owner: owner, repo: repo, number: pullRequest.number) { detailResult in
                        DispatchQueue.main.async {
                            if case .success(let updatedPR) = detailResult {
                                pullRequest = updatedPR
                            }
                        }
                    }
                case .failure(let error):
                    commentsError = "合并失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 关闭PR
    private func closePR() {
        isUpdatingState = true
        GitHubAPI.shared.updatePullRequestState(owner: owner, repo: repo, number: pullRequest.number, state: "closed") { result in
            DispatchQueue.main.async {
                isUpdatingState = false
                switch result {
                case .success(let updatedPR):
                    pullRequest = updatedPR
                case .failure(let error):
                    commentsError = "关闭失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 重新打开PR
    private func reopenPR() {
        isUpdatingState = true
        GitHubAPI.shared.updatePullRequestState(owner: owner, repo: repo, number: pullRequest.number, state: "open") { result in
            DispatchQueue.main.async {
                isUpdatingState = false
                switch result {
                case .success(let updatedPR):
                    pullRequest = updatedPR
                case .failure(let error):
                    commentsError = "重新打开失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
