import SwiftUI

// MARK: - 仓库设置视图
struct RepositorySettingsView: View {
    let owner: String
    let repo: String
    @EnvironmentObject var appState: AppState

    // 仓库信息
    @State private var repository: Repository?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // 编辑状态
    @State private var showEditName: Bool = false
    @State private var showEditDescription: Bool = false
    @State private var newName: String = ""
    @State private var newDescription: String = ""
    @State private var isSaving: Bool = false

    // 切换公开/私有
    @State private var showToggleVisibilityConfirm: Bool = false
    @State private var isTogglingVisibility: Bool = false

    // 删除仓库
    @State private var showDeleteConfirm: Bool = false
    @State private var deleteConfirmationText: String = ""
    @State private var isDeleting: Bool = false

    // 是否是自己的仓库（决定是否显示编辑选项）
    private var isOwnRepository: Bool {
        guard let currentUsername = AccountManager.shared.currentAccount?.username else { return false }
        return owner.lowercased() == currentUsername.lowercased()
    }

    var body: some View {
        Form {
            if isLoading && repository == nil {
                loadingSection
            } else if let error = errorMessage, repository == nil {
                errorSection(error: error)
            } else if let repo = repository {
                // 仓库基本信息
                basicInfoSection(repo: repo)

                // 如果是自己的仓库，显示设置选项
                if isOwnRepository {
                    settingsSection(repo: repo)
                    dangerZoneSection(repo: repo)
                } else {
                    // 别人的仓库，只显示信息
                    otherRepoInfoSection(repo: repo)
                }
            }
        }
        .navigationTitle("仓库设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if repository == nil {
                loadRepository()
            }
        }
        .ios14Refreshable {
            loadRepository()
        }
        .alert("重命名仓库", isPresented: $showEditName) {
            TextField("新仓库名称", text: $newName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                saveRepositoryName()
            }
            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        } message: {
            Text("请输入新的仓库名称。重命名后，旧的URL会自动重定向到新地址。")
        }
        .alert("修改描述", isPresented: $showEditDescription) {
            TextField("仓库描述", text: $newDescription)
            Button("取消", role: .cancel) {}
            Button("保存") {
                saveRepositoryDescription()
            }
            .disabled(isSaving)
        } message: {
            Text("请输入新的仓库描述。")
        }
        .alert("确认切换可见性", isPresented: $showToggleVisibilityConfirm) {
            Button("取消", role: .cancel) {}
            Button(repository?.isPrivate == true ? "设为公开" : "设为私有", role: .destructive) {
                toggleVisibility()
            }
        } message: {
            if repository?.isPrivate == true {
                Text("确定要将此仓库设为公开吗？设为公开后，任何人都可以查看此仓库的内容。")
            } else {
                Text("确定要将此仓库设为私有吗？设为私有后，只有您和您授权的协作者可以查看此仓库。")
            }
        }
        .alert("删除仓库", isPresented: $showDeleteConfirm) {
            TextField("请输入仓库名称「\(repository?.name ?? "")」确认", text: $deleteConfirmationText)
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteRepository()
            }
            .disabled(deleteConfirmationText != repository?.name || isDeleting)
        } message: {
            Text("此操作不可撤销！删除后，仓库的所有代码、Issue、Pull Request和设置都将被永久删除。")
        }
        .overlay {
            if isSaving || isTogglingVisibility || isDeleting {
                ProgressView("处理中...")
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }
        }
    }

    // MARK: - 加载中
    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - 错误
    private func errorSection(error: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    loadRepository()
                }
                
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - 基本信息
    private func basicInfoSection(repo: Repository) -> some View {
        Section("基本信息") {
            HStack {
                Text("仓库名称")
                Spacer()
                Text(repo.name)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("完整名称")
                Spacer()
                Text(repo.fullName)
                    .foregroundColor(.secondary)
            }

            if let description = repo.description, !description.isEmpty {
                HStack(alignment: .top) {
                    Text("描述")
                    Spacer()
                    Text(description)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Text("可见性")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                    Text(repo.isPrivate ? "私有" : "公开")
                }
                .foregroundColor(repo.isPrivate ? .orange : .green)
            }

            if let language = repo.language {
                HStack {
                    Text("主要语言")
                    Spacer()
                    Text(language)
                        .foregroundColor(.secondary)
                }
            }

            if let defaultBranch = repo.defaultBranch {
                HStack {
                    Text("默认分支")
                    Spacer()
                    Text(defaultBranch)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("创建时间")
                Spacer()
                Text(repo.formattedCreateTime ?? "未知")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("更新时间")
                Spacer()
                Text(repo.formattedUpdateTime)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 设置选项（仅自己的仓库）
    private func settingsSection(repo: Repository) -> some View {
        Section("仓库设置") {
            Button(action: {
                newName = repo.name
                showEditName = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                    Text("重命名仓库")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                newDescription = repo.description ?? ""
                showEditDescription = true
            }) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.blue)
                    Text("修改描述")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                showToggleVisibilityConfirm = true
            }) {
                HStack {
                    Image(systemName: repo.isPrivate ? "globe" : "lock")
                        .foregroundColor(.blue)
                    Text(repo.isPrivate ? "设为公开" : "设为私有")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }

            NavigationLink(destination: RepositoryStatsView(owner: owner, repo: repo.name)) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.blue)
                    Text("仓库统计")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 危险操作区（仅自己的仓库）
    private func dangerZoneSection(repo: Repository) -> some View {
        Section("危险操作") {
            Button(role: .destructive, action: {
                deleteConfirmationText = ""
                showDeleteConfirm = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除仓库")
                    Spacer()
                }
            }
        }
    }

    // MARK: - 别人仓库信息
    private func otherRepoInfoSection(repo: Repository) -> some View {
        Section("仓库统计") {
            HStack {
                Text("星标数")
                Spacer()
                Text("\(repo.stargazersCount ?? 0)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Fork数")
                Spacer()
                Text("\(repo.forksCount ?? 0)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Watch数")
                Spacer()
                Text("\(repo.watchersCount ?? 0)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("开放Issue数")
                Spacer()
                Text("\(repo.openIssuesCount ?? 0)")
                    .foregroundColor(.secondary)
            }

            if let size = repo.size {
                HStack {
                    Text("仓库大小")
                    Spacer()
                    Text(repo.formattedSize)
                        .foregroundColor(.secondary)
                }
            }

            if let license = repo.license {
                HStack {
                    Text("开源协议")
                    Spacer()
                    Text(license.name)
                        .foregroundColor(.secondary)
                }
            }

            if let topics = repo.topics, !topics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("标签")
                    FlowLayout(spacing: 6) {
                        ForEach(topics, id: \.self) { topic in
                            Text(topic)
                                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                                .padding(.vertical, 3)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                        }
                    }
                }
            }
        }
    }

    // MARK: - 加载仓库信息
    private func loadRepository() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getRepository(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let repoInfo):
                    repository = repoInfo
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 保存仓库名称
    private func saveRepositoryName() {
        isSaving = true
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        GitHubAPI.shared.updateRepository(owner: owner, repo: repo, name: name) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    showEditName = false
                    // 重新加载仓库信息
                    loadRepository()
                case .failure(let error):
                    errorMessage = "重命名失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 保存仓库描述
    private func saveRepositoryDescription() {
        isSaving = true
        let description = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        GitHubAPI.shared.updateRepository(owner: owner, repo: repo, description: description) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    showEditDescription = false
                    // 重新加载仓库信息
                    loadRepository()
                case .failure(let error):
                    errorMessage = "修改描述失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 切换可见性
    private func toggleVisibility() {
        isTogglingVisibility = true
        guard let currentRepo = repository else { return }
        let newIsPrivate = !currentRepo.isPrivate

        GitHubAPI.shared.updateRepository(owner: owner, repo: repo, isPrivate: newIsPrivate) { result in
            DispatchQueue.main.async {
                isTogglingVisibility = false
                switch result {
                case .success:
                    // 重新加载仓库信息
                    loadRepository()
                case .failure(let error):
                    errorMessage = "切换可见性失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 删除仓库
    private func deleteRepository() {
        isDeleting = true

        GitHubAPI.shared.deleteRepository(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isDeleting = false
                switch result {
                case .success:
                    // 删除成功，返回上一页
                    showDeleteConfirm = false
                    // 通知上层刷新仓库列表
                    NotificationCenter.default.post(name: NSNotification.Name("RepositoryDeleted"), object: nil)
                case .failure(let error):
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 流式布局（用于标签展示）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += subview.sizeThatFits(.unspecified).width + spacing
            }
            y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [(subviews: [LayoutSubview], height: CGFloat)] {
        var rows: [(subviews: [LayoutSubview], height: CGFloat)] = []
        var currentRow: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !currentRow.isEmpty {
                rows.append((currentRow, currentHeight))
                currentRow = []
                currentWidth = 0
                currentHeight = 0
            }
            currentRow.append(subview)
            currentWidth += size.width + spacing
            currentHeight = max(currentHeight, size.height)
        }
        if !currentRow.isEmpty {
            rows.append((currentRow, currentHeight))
        }
        return rows
    }
}
