import SwiftUI

// MARK: - Issue详情视图
struct IssueDetailView: View {
    let owner: String
    let repo: String
    @State var issue: Issue
    @EnvironmentObject var appState: AppState

    // 评论列表状态
    @State private var comments: [IssueComment] = []
    @State private var isLoadingComments: Bool = false
    @State private var commentsError: String?

    // 添加评论
    @State private var newComment: String = ""
    @State private var isAddingComment: Bool = false

    // 关闭/重新打开
    @State private var isUpdatingState: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Issue头部信息
                issueHeader

                // Issue描述
                if let body = issue.body, !body.isEmpty {
                    issueBody(body)
                }

                // 评论列表
                commentsSection

                // 添加评论
                addCommentSection
            }
            .padding()
        }
        .navigationTitle("#\(issue.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if issue.state == .open {
                        Button(role: .destructive) {
                            closeIssue()
                        } label: {
                            Label("关闭Issue", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            reopenIssue()
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
            loadComments()
        }
        .overlay {
            if isUpdatingState {
                ProgressView("处理中...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度
            }
        }
    }

    // MARK: - Issue头部信息
    private var issueHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(issue.title)
                .font(.system(size: 20, weight: .bold))  // 字体大小20pt，控制文字显示尺寸
                .foregroundColor(appState.isDarkMode ? .white : .primary)

            // 状态和元信息
            HStack(spacing: 12) {
                // 状态标签
                HStack(spacing: 4) {
                    Image(systemName: issue.state.图标名称)
                    Text(issue.state.显示文本)
                }
                .font(.system(size: 13, weight: .medium))  // 字体大小13pt，控制文字显示尺寸
                .padding(.horizontal, 10)  // 水平内边距10pt，控制左右留白间距
                .padding(.vertical, 4)  // 垂直内边距4pt，控制上下留白间距
                .background(issue.state.颜色.opacity(0.15))
                .foregroundColor(issue.state.颜色)
                .cornerRadius(12)  // 圆角半径12pt，控制视图边角圆润程度

                Text("#\(issue.number)")
                    .font(.system(size: 14))  // 字体大小14pt，控制文字显示尺寸
                    .foregroundColor(.secondary)

                Text("由 \(issue.user.login) 创建于 \(issue.创建时间显示)")
                    .font(.system(size: 13))  // 字体大小13pt，控制文字显示尺寸
                    .foregroundColor(.secondary)
            }

            // 标签
            if let labels = issue.labels, !labels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(labels) { label in
                        Text(label.name)
                            .font(.system(size: 12))  // 字体大小12pt，控制文字显示尺寸
                            .padding(.horizontal, 8)  // 水平内边距8pt，控制左右留白间距
                            .padding(.vertical, 3)  // 垂直内边距3pt，控制上下留白间距
                            .background(label.背景颜色)
                            .foregroundColor(label.文字颜色)
                            .cornerRadius(4)  // 圆角半径4pt，控制视图边角圆润程度
                    }
                }
            }

            // 里程碑
            if let milestone = issue.milestone {
                HStack(spacing: 4) {
                    Image(systemName: "milestone")
                        .font(.system(size: 12))  // 字体大小12pt，控制文字显示尺寸
                    Text(milestone.title)
                        .font(.system(size: 12))  // 字体大小12pt，控制文字显示尺寸
                }
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Issue描述
    private func issueBody(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 用户信息
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: issue.user.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 28, height: 28)  // 视图尺寸宽28pt高28pt，控制组件显示大小
                .clipShape(Circle())

                Text(issue.user.login)
                    .font(.system(size: 14, weight: .semibold))  // 字体大小14pt，控制文字显示尺寸

                Text(issue.创建时间显示)
                    .font(.system(size: 12))  // 字体大小12pt，控制文字显示尺寸
                    .foregroundColor(.secondary)
            }

            // 描述内容
            Text(body)
                .font(.system(size: 14))  // 字体大小14pt，控制文字显示尺寸
                .foregroundColor(appState.isDarkMode ? .white.opacity(0.9) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)  // 四向统一内边距12pt，控制上下左右留白
                .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度
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
                    .font(.system(size: 16, weight: .semibold))  // 字体大小16pt，控制文字显示尺寸

                if isLoadingComments {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if let error = commentsError {
                    Text(error)
                        .font(.system(size: 13))  // 字体大小13pt，控制文字显示尺寸
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
    private func commentRow(_ comment: IssueComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 用户信息
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: comment.user.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 28, height: 28)  // 视图尺寸宽28pt高28pt，控制组件显示大小
                .clipShape(Circle())

                Text(comment.user.login)
                    .font(.system(size: 14, weight: .semibold))  // 字体大小14pt，控制文字显示尺寸

                Text(comment.创建时间显示)
                    .font(.system(size: 12))  // 字体大小12pt，控制文字显示尺寸
                    .foregroundColor(.secondary)
            }

            // 评论内容
            if let body = comment.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14))  // 字体大小14pt，控制文字显示尺寸
                    .foregroundColor(appState.isDarkMode ? .white.opacity(0.9) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)  // 四向统一内边距12pt，控制上下左右留白
                    .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                    .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度
            }
        }
    }

    // MARK: - 添加评论
    private var addCommentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("添加评论")
                .font(.system(size: 16, weight: .semibold))  // 字体大小16pt，控制文字显示尺寸

            TextEditor(text: $newComment)
                .font(.system(size: 14))  // 字体大小14pt，控制文字显示尺寸
                .frame(minHeight: 80)
                .padding(8)  // 四向统一内边距8pt，控制上下左右留白
                .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度

            HStack {
                Spacer()
                Button(action: { addComment() }) {
                    if isAddingComment {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("发表评论")
                            .font(.system(size: 14, weight: .medium))  // 字体大小14pt，控制文字显示尺寸
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingComment)
            }
        }
    }

    // MARK: - 加载评论
    private func loadComments() {
        isLoadingComments = true
        commentsError = nil

        GitHubAPI.shared.getIssueComments(owner: owner, repo: repo, number: issue.number) { result in
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

    // MARK: - 添加评论
    private func addComment() {
        isAddingComment = true
        let body = newComment.trimmingCharacters(in: .whitespacesAndNewlines)

        GitHubAPI.shared.createIssueComment(owner: owner, repo: repo, number: issue.number, body: body) { result in
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

    // MARK: - 关闭Issue
    private func closeIssue() {
        isUpdatingState = true
        GitHubAPI.shared.updateIssueState(owner: owner, repo: repo, number: issue.number, state: "closed") { result in
            DispatchQueue.main.async {
                isUpdatingState = false
                switch result {
                case .success(let updatedIssue):
                    issue = updatedIssue
                case .failure(let error):
                    commentsError = "关闭失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 重新打开Issue
    private func reopenIssue() {
        isUpdatingState = true
        GitHubAPI.shared.updateIssueState(owner: owner, repo: repo, number: issue.number, state: "open") { result in
            DispatchQueue.main.async {
                isUpdatingState = false
                switch result {
                case .success(let updatedIssue):
                    issue = updatedIssue
                case .failure(let error):
                    commentsError = "重新打开失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
