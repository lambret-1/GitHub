import SwiftUI

// MARK: - 工作流触发器

struct TriggerWorkflowView: View {
    let owner: String
    let repo: String
    let workflow: Workflow

    @State private var selectedBranch: String = "main"
    @State private var branches: [Branch] = []
    @State private var isLoadingBranches: Bool = true
    @State private var branchError: String?
    @State private var inputs: [String: String] = [:]
    @State private var inputKeys: [String] = []
    @State private var isTriggering: Bool = false
    @State private var triggerSuccess: Bool = false
    @State private var triggerError: String?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                // 工作流信息
                Section(header: Text("工作流信息")) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workflow.name)
                                .font(.headline)
                            Text(workflow.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 分支选择
                Section(header: Text("选择分支")) {
                    if isLoadingBranches {
                        HStack {
                            ProgressView()
                            Text("加载分支列表中...")
                                .foregroundColor(.secondary)
                        }
                    } else if let error = branchError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("重试") {
                                loadBranches()
                            }
                        }
                    } else {
                        Picker("分支", selection: $selectedBranch) {
                            ForEach(branches, id: \.name) { branch in
                                HStack {
                                    Image(systemName: "branch")
                                        .foregroundColor(.purple)
                                    Text(branch.name)
                                }
                                .tag(branch.name)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }

                // 输入参数（如果有）
                if !inputKeys.isEmpty {
                    Section(header: Text("输入参数")) {
                        ForEach(inputKeys, id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.subheadline)
                                    .frame(width: 100, alignment: .leading)
                                TextField("输入值", text: Binding(
                                    get: { inputs[key] ?? "" },
                                    set: { inputs[key] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.subheadline)
                            }
                        }
                    }
                }

                // 触发按钮
                Section {
                    Button(action: {
                        triggerWorkflow()
                    }) {
                        HStack {
                            Spacer()
                            if isTriggering {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("触发中...")
                            } else if triggerSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("触发成功")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.green)
                                Text("触发工作流")
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isTriggering || triggerSuccess)
                }

                // 错误提示
                if let error = triggerError {
                    Section {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("触发工作流")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(!triggerSuccess)
            )
            .onAppear {
                loadBranches()
                parseWorkflowInputs()
            }
        }
    }

    // MARK: - 加载分支列表

    private func loadBranches() {
        isLoadingBranches = true
        branchError = nil

        GitHubAPI.shared.getBranches(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoadingBranches = false
                switch result {
                case .success(let branches):
                    self.branches = branches
                    // 默认选择main分支，如果不存在则选择第一个
                    if !branches.contains(where: { $0.name == "main" }) {
                        self.selectedBranch = branches.first?.name ?? "main"
                    }
                case .failure(let error):
                    self.branchError = "加载分支失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 解析工作流输入参数

    private func parseWorkflowInputs() {
        // 从工作流文件路径中解析输入参数
        // 注意：GitHub API的workflow_dispatch事件的inputs需要从工作流文件中解析
        // 这里我们先尝试获取工作流文件内容来解析inputs
        GitHubAPI.shared.getFileContent(owner: owner, repo: repo, path: workflow.path) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileContent):
                    if let content = fileContent.decodedContent {
                        self.parseInputsFromYAML(content)
                    }
                case .failure:
                    // 如果获取文件内容失败，则不显示输入参数
                    break
                }
            }
        }
    }

    // MARK: - 从YAML中解析输入参数

    private func parseInputsFromYAML(_ content: String) {
        var keys: [String] = []
        var inInputsSection = false
        var inputsIndentation = 0

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 检测inputs: 关键字
            if trimmed == "inputs:" || trimmed.hasSuffix("inputs:") {
                inInputsSection = true
                inputsIndentation = line.prefix(while: { $0 == " " }).count
                continue
            }

            // 如果在inputs区域内
            if inInputsSection {
                let currentIndentation = line.prefix(while: { $0 == " " }).count

                // 如果遇到与inputs同级或更高级别的键，则退出inputs区域
                if currentIndentation <= inputsIndentation && !trimmed.isEmpty {
                    inInputsSection = false
                    continue
                }

                // 解析输入参数键（缩进比inputs多一级，且以:结尾）
                if currentIndentation > inputsIndentation && trimmed.contains(":") {
                    let key = String(trimmed.split(separator: ":").first ?? "")
                    if !key.isEmpty && !keys.contains(key) {
                        keys.append(key)
                        inputs[key] = ""
                    }
                }
            }
        }

        self.inputKeys = keys
    }

    // MARK: - 触发工作流

    private func triggerWorkflow() {
        isTriggering = true
        triggerError = nil
        triggerSuccess = false

        // 过滤掉空值的输入参数
        let filteredInputs = inputs.filter { !$0.value.isEmpty }

        GitHubAPI.shared.triggerWorkflowDispatch(
            owner: owner,
            repo: repo,
            workflowId: workflow.id,
            ref: selectedBranch,
            inputs: filteredInputs
        ) { result in
            DispatchQueue.main.async {
                isTriggering = false
                switch result {
                case .success:
                    triggerSuccess = true
                    // 2秒后自动关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        presentationMode.wrappedValue.dismiss()
                    }
                case .failure(let error):
                    triggerError = "触发失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
