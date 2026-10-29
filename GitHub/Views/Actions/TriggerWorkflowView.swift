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
    @State private var isLoadingInputs: Bool = true
    @State private var inputError: String?
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

                // 输入参数：明确显示加载/读取错误，避免解析失败时看起来像选项被删除。
                if isLoadingInputs {
                    Section(header: Text("输入参数")) {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在读取工作流参数…")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !inputKeys.isEmpty {
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
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                } else if let error = inputError {
                    Section(header: Text("输入参数")) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Button("重试读取参数") {
                            parseWorkflowInputs(branch: selectedBranch)
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
                parseWorkflowInputs(branch: selectedBranch)
            }
            .onChange(of: selectedBranch) { newBranch in
                parseWorkflowInputs(branch: newBranch)
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
                    self.parseWorkflowInputs(branch: self.selectedBranch)
                case .failure(let error):
                    self.branchError = "加载分支失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 解析工作流输入参数

    private func parseWorkflowInputs(branch: String) {
        isLoadingInputs = true
        inputError = nil

        GitHubAPI.shared.getFileContent(owner: owner, repo: repo, path: workflow.path, branch: branch) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileContent):
                    let content = fileContent.decodedContent
                    self.parseInputsFromYAML(content)
                    self.isLoadingInputs = false
                case .failure(let error):
                    self.inputKeys = []
                    self.inputOptions = [:]
                    self.inputDefaults = [:]
                    self.inputs = [:]
                    self.inputError = "无法读取工作流参数：\(error.localizedDescription)"
                    self.isLoadingInputs = false
                }
            }
        }
    }

    // MARK: - 从 YAML 中解析 workflow_dispatch.inputs
    // 只解析 on.workflow_dispatch.inputs，避免误把 job/step 的 inputs 当作手动触发参数。

    private func parseInputsFromYAML(_ content: String) {
        struct YAMLLine {
            let text: String
            let indentation: Int
        }
        let lines: [YAMLLine] = content.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            return YAMLLine(
                text: trimmed,
                indentation: line.prefix(while: { $0 == " " }).count
            )
        }

        var inOnSection = false
        var onIndentation = 0
        var dispatchIndentation: Int?
        var inputsIndentation: Int?
        var currentKey: String?
        var optionsIndentation: Int?
        var parsedKeys: [String] = []
        var parsedOptions: [String: [String]] = [:]
        var parsedDefaults: [String: String] = [:]

        for line in lines {
            if line.text == "on:" || line.text.hasPrefix("on: #") {
                inOnSection = true
                onIndentation = line.indentation
                dispatchIndentation = nil
                inputsIndentation = nil
                currentKey = nil
                continue
            }

            guard inOnSection else { continue }
            if line.indentation <= onIndentation {
                inOnSection = false
                dispatchIndentation = nil
                inputsIndentation = nil
                currentKey = nil
                continue
            }

            if dispatchIndentation == nil,
               line.indentation > onIndentation,
               line.text.hasPrefix("workflow_dispatch:") {
                dispatchIndentation = line.indentation
                continue
            }

            guard let dispatchIndentation = dispatchIndentation else { continue }
            if line.indentation <= dispatchIndentation {
                dispatchIndentation = nil
                inputsIndentation = nil
                currentKey = nil
                optionsIndentation = nil
                continue
            }

            if inputsIndentation == nil, line.text == "inputs:", line.indentation > dispatchIndentation {
                inputsIndentation = line.indentation
                continue
            }

            guard let inputsIndentation = inputsIndentation else { continue }
            if line.indentation <= inputsIndentation {
                inputsIndentation = nil
                currentKey = nil
                optionsIndentation = nil
                continue
            }

            if line.indentation == inputsIndentation + 2,
               line.text.hasSuffix(":"),
               !line.text.hasPrefix("-") {
                let key = String(line.text.dropLast()).trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                if !parsedKeys.contains(key) { parsedKeys.append(key) }
                currentKey = key
                optionsIndentation = nil
                continue
            }

            guard let key = currentKey else { continue }
            if line.indentation == inputsIndentation + 4 {
                if line.text == "options:" {
                    optionsIndentation = line.indentation
                } else {
                    optionsIndentation = nil
                    if line.text.hasPrefix("default:") {
                        let value = String(line.text.dropFirst("default:".count))
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        parsedDefaults[key] = value
                    }
                }
                continue
            }

            if let optionsIndentation,
               line.indentation > optionsIndentation,
               line.text.hasPrefix("-") {
                let option = String(line.text.dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !option.isEmpty, !parsedOptions[key, default: []].contains(option) {
                    parsedOptions[key, default: []].append(option)
                }
            }
        }

        inputKeys = parsedKeys
        inputOptions = parsedOptions
        inputDefaults = parsedDefaults
        inputs = Dictionary(uniqueKeysWithValues: parsedKeys.map {
            ($0, parsedDefaults[$0] ?? parsedOptions[$0]?.first ?? "")
        })
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
