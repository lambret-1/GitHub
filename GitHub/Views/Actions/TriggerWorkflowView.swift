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
    @State private var inputOptions: [String: [String]] = [:]
    @State private var inputDefaults: [String: String] = [:]
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
                                if let options = inputOptions[key], !options.isEmpty {
                                    Picker(key, selection: Binding(
                                        get: { inputs[key] ?? inputDefaults[key] ?? options[0] },
                                        set: { inputs[key] = $0 }
                                    )) {
                                        ForEach(options, id: \.self) { option in
                                            Text(option).tag(option)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                } else {
                                    TextField("输入值", text: Binding(
                                        get: { inputs[key] ?? inputDefaults[key] ?? "" },
                                        set: { inputs[key] = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.subheadline())
                                }
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
                    let content = fileContent.decodedContent
                    if !content.isEmpty {
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
        var parsedKeys: [String] = []
        var parsedOptions: [String: [String]] = [:]
        var parsedDefaults: [String: String] = [:]
        var inInputsSection = false
        var inputsIndentation = 0
        var currentKey: String?
        var inOptions = false
        var optionsIndentation = 0

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indentation = line.prefix(while: { $0 == " " }).count

            if trimmed == "inputs:" {
                inInputsSection = true
                inputsIndentation = indentation
                currentKey = nil
                inOptions = false
                continue
            }
            guard inInputsSection else { continue }
            if indentation <= inputsIndentation {
                inInputsSection = false
                currentKey = nil
                inOptions = false
                continue
            }

            if indentation == inputsIndentation + 2,
               trimmed.hasSuffix(":"),
               !trimmed.hasPrefix("-") {
                let key = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                if !parsedKeys.contains(key) { parsedKeys.append(key) }
                currentKey = key
                inOptions = false
                continue
            }

            guard let key = currentKey else { continue }
            if indentation == inputsIndentation + 4 {
                if trimmed == "options:" {
                    inOptions = true
                    optionsIndentation = indentation
                } else {
                    inOptions = false
                    if trimmed.hasPrefix("default:") {
                        let value = String(trimmed.dropFirst("default:".count))
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        if !value.isEmpty { parsedDefaults[key] = value }
                    }
                }
                continue
            }

            if inOptions && indentation > optionsIndentation && trimmed.hasPrefix("-") {
                let option = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !option.isEmpty {
                    parsedOptions[key, default: []].append(option)
                }
            }
        }

        self.inputKeys = parsedKeys
        self.inputOptions = parsedOptions
        self.inputDefaults = parsedDefaults
        for key in parsedKeys where inputs[key] == nil {
            inputs[key] = parsedDefaults[key] ?? parsedOptions[key]?.first ?? ""
        }
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
