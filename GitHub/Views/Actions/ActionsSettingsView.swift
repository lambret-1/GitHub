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
            Section("管理工具") {
                NavigationLink(destination: CacheManagementView(owner: owner, repo: repo)) {
                    HStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("缓存管理")
                                .font(.subheadline)
                            Text("查看和删除Actions缓存")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink(destination: RunnerManagementView(owner: owner, repo: repo)) {
                    HStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Runner管理")
                                .font(.subheadline)
                            Text("查看和管理自助托管Runner")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }

            // 工作流管理
            Section("工作流管理") {
                if isLoadingWorkflows && workflows.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("加载工作流中...")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
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
                    .listRowSeparator(.hidden)
                } else if workflows.isEmpty {
                    Text("暂无工作流")
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(workflows) { workflow in
                        WorkflowSettingsRow(owner: owner, repo: repo, workflow: workflow)
                    }
                }
            }

            // 说明
            Section("说明") {
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
                .padding(.vertical, 4)
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
                .frame(width: 24)

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
                    .scaleEffect(0.8)
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
        .padding(.vertical, 4)
        .alert("操作结果", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
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
