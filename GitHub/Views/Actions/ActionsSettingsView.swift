import SwiftUI

// MARK: - Actions设置页面

struct ActionsSettingsView: View {
    let owner: String
    let repo: String

    @State private var workflows: [Workflow] = []
    @State private var isLoadingWorkflows: Bool = true
    @State private var workflowsError: String?

    var body: some View {
        List {
            // 管理工具
            Section(header: Text("管理工具")) { // iOS14兼容：使用旧版Section语法
                NavigationLink(destination: CacheManagementView(owner: owner, repo: repo)) {
                    HStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .foregroundColor(.blue)
                            .frame(width: 24)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                        VStack(alignment: .leading, spacing: 2) {
                            Text("缓存管理")
                                .font(.subheadline)
                            Text("查看和删除Actions缓存")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                }

                NavigationLink(destination: RunnerManagementView(owner: owner, repo: repo)) {
                    HStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                            .frame(width: 24)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Runner管理")
                                .font(.subheadline)
                            Text("查看和管理自助托管Runner")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                }
            }

            // 工作流管理
            Section(header: Text("工作流管理")) { // iOS14兼容：使用旧版Section语法
                if isLoadingWorkflows && workflows.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("加载工作流中...")
                        Spacer()
                    }
                    .ios14HideListRowSeparator()
                } else if let error = workflowsError, workflows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            loadWorkflows()
                        }
                        .font(.caption)
                    }
                    .padding(.vertical)
                    .ios14HideListRowSeparator()
                } else if workflows.isEmpty {
                    Text("暂无工作流")
                        .foregroundColor(.secondary)
                        .ios14HideListRowSeparator()
                } else {
                    ForEach(workflows) { workflow in
                        WorkflowSettingsRow(owner: owner, repo: repo, workflow: workflow)
                    }
                }
            }

            // 说明
            Section(header: Text("说明")) { // iOS14兼容：使用旧版Section语法
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions设置")
                        .font(.headline)
                    Text("在此页面可以管理Actions缓存、自助托管Runner和工作流状态。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("禁用工作流后，该工作流将不会自动触发，但仍可以手动触发。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Actions设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if workflows.isEmpty {
                loadWorkflows()
            }
        }
    }

    // MARK: - 加载工作流

    private func loadWorkflows() {
        isLoadingWorkflows = true
        workflowsError = nil

        GitHubAPI.shared.getWorkflows(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoadingWorkflows = false
                switch result {
                case .success(let workflows):
                    self.workflows = workflows
                case .failure(let error):
                    self.workflowsError = "加载工作流失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 工作流设置行

struct WorkflowSettingsRow: View {
    let owner: String
    let repo: String
    @State var workflow: Workflow

    @State private var isUpdating: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .foregroundColor(workflow.state == "active" ? .green : .gray)
                .frame(width: 24)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(workflow.fileName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 状态开关
            if isUpdating {
                ProgressView()
                    .scaleEffect(0.8)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置
            } else {
                Toggle("", isOn: Binding(
                    get: { workflow.state == "active" },
                    set: { newValue in
                        toggleWorkflowState(enabled: newValue)
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .green))
            }
        }
        .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .alert(isPresented: $showAlert) { // iOS14兼容：使用旧版Alert语法
            Alert(
                title: Text("操作结果"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
    }

    // MARK: - 切换工作流状态

    private func toggleWorkflowState(enabled: Bool) {
        isUpdating = true

        if enabled {
            GitHubAPI.shared.enableWorkflow(owner: owner, repo: repo, workflowId: workflow.id) { result in
                DispatchQueue.main.async {
                    isUpdating = false
                    switch result {
                    case .success:
                        workflow.state = "active"
                        alertMessage = "工作流已启用"
                        showAlert = true
                    case .failure(let error):
                        alertMessage = "启用失败: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        } else {
            GitHubAPI.shared.disableWorkflow(owner: owner, repo: repo, workflowId: workflow.id) { result in
                DispatchQueue.main.async {
                    isUpdating = false
                    switch result {
                    case .success:
                        workflow.state = "disabled_manually"
                        alertMessage = "工作流已禁用"
                        showAlert = true
                    case .failure(let error):
                        alertMessage = "禁用失败: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        }
    }
}
