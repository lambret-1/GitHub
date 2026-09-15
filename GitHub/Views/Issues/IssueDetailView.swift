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
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }
        }
    }

    // MARK: - Issue头部信息
    private var issueHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(issue.title)
                .font(.system(size: 20, weight: .bold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(appState.isDarkMode ? .white : .primary)

            // 状态和元信息
            HStack(spacing: 12) {
                // 状态标签
                HStack(spacing: 4) {
                    Image(systemName: issue.state.图标名称)
                    Text(issue.state.显示文本)
                }
                .font(.system(size: 13, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .padding(.horizontal, 10)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(issue.state.颜色.opacity(0.15))
                .foregroundColor(issue.state.颜色)
                .cornerRadius(12)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑

                Text("#\(issue.number)")
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)

                Text("由 \(issue.user.login) 创建于 \(issue.创建时间显示)")
                    .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }

            // 标签
            if let labels = issue.labels, !labels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(labels) { label in
                        Text(label.name)
                            .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                            .padding(.vertical, 3)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                            .background(label.背景颜色)
                            .foregroundColor(label.文字颜色)
                            .cornerRadius(4)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    }
                }
            }

            // 里程碑
            if let milestone = issue.milestone {
                HStack(spacing: 4) {
                    Image(systemName: "milestone")
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    Text(milestone.title)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
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
                iOS14AsyncImage(url: URL(string: issue.user.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 28, height: 28)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                .clipShape(Circle())

                Text(issue.user.login)
                    .font(.system(size: 14, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）

                Text(issue.创建时间显示)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }

            // 描述内容
            Text(body)
                .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(appState.isDarkMode ? .white.opacity(0.9) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                .ios14TextSelection()  // 启用文本选择，长按可选择文字并弹出拷贝/分享/查找菜单
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
                    .font(.system(size: 16, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）

                if isLoadingComments {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if let error = commentsError {
                    Text(error)
                        .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(Color.red)
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
                iOS14AsyncImage(url: URL(string: comment.user.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 28, height: 28)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                .clipShape(Circle())

                Text(comment.user.login)
                    .font(.system(size: 14, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）

                Text(comment.创建时间显示)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }

            // 评论内容
            if let body = comment.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(appState.isDarkMode ? .white.opacity(0.9) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                    .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    .ios14TextSelection()  // 启用文本选择，长按可选择文字并弹出拷贝/分享/查找菜单
            }
        }
    }

    // MARK: - 添加评论
    private var addCommentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("添加评论")
                .font(.system(size: 16, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）

            TextEditor(text: $newComment)
                .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .frame(minHeight: 80)
                .padding(8)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑

            HStack {
                Spacer()
                Button(action: { addComment() }) {
                    if isAddingComment {
                        ProgressView()
                            .ios14Tint(.white)
                    } else {
                        Text("发表评论")
                            .font(.system(size: 14, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    }
                }
                
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
