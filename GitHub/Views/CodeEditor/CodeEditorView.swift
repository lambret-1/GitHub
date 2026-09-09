import SwiftUI

struct CodeEditorView: View {
    let owner: String
    let repo: String
    let path: String
    let branch: String
    let fileName: String
    
    @State private var fileContent: FileContent?
    @State private var codeText: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var isEditing: Bool = false
    @State private var showCommitDialog: Bool = false
    @State private var commitMessage: String = ""
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false
    @State private var showLineNumbers: Bool = true
    @State private var fontSize: CGFloat = 14
    @State private var showSettings: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("加载文件中...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        loadFile()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else if let content = fileContent {
                if !content.isTextFile {
                    // 二进制文件提示
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("此文件为二进制文件，无法在线编辑")
                            .foregroundColor(.secondary)
                        if let downloadUrl = content.downloadUrl {
                            Button("下载文件") {
                                if let url = URL(string: downloadUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Spacer()
                } else {
                    // 代码编辑器
                    codeEditorArea
                }
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if fileContent?.isTextFile ?? false {
                        Button(action: {
                            isEditing.toggle()
                        }) {
                            Label(isEditing ? "完成编辑" : "编辑文件", systemImage: isEditing ? "checkmark" : "pencil")
                        }
                        
                        Button(action: {
                            UIPasteboard.general.string = codeText
                        }) {
                            Label("复制全部内容", systemImage: "doc.on.doc")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showLineNumbers.toggle()
                        }) {
                            Label(showLineNumbers ? "隐藏行号" : "显示行号", systemImage: "number")
                        }
                        
                        Button(action: {
                            fontSize = max(10, fontSize - 1)
                        }) {
                            Label("减小字号", systemImage: "textformat.size.smaller")
                        }
                        
                        Button(action: {
                            fontSize = min(24, fontSize + 1)
                        }) {
                            Label("增大字号", systemImage: "textformat.size.larger")
                        }
                    }
                    
                    if let htmlUrl = fileContent?.htmlUrl {
                        Divider()
                        Button(action: {
                            if let url = URL(string: htmlUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("在 GitHub 打开", systemImage: "safari")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("提交修改", isPresented: $showCommitDialog) {
            TextField("提交信息（如：更新 xxx）", text: $commitMessage)
            Button("取消", role: .cancel) {}
            Button("提交") {
                commitChanges()
            }
        } message: {
            Text("将修改提交到 \(branch) 分支")
        }
        .alert("提交成功", isPresented: $showSaveSuccess) {
            Button("确定") {
                isEditing = false
                loadFile()
            }
        } message: {
            Text("文件已成功提交到 GitHub 仓库")
        }
        .onAppear {
            loadFile()
        }
    }
    
    // 代码编辑区域
    private var codeEditorArea: some View {
        VStack(spacing: 0) {
            // 编辑模式提示条
            if isEditing {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                    Text("编辑模式")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                    if hasChanges {
                        Text("已修改")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                
                // 提交按钮
                HStack(spacing: 12) {
                    Button(action: {
                        codeText = originalContent
                        isEditing = false
                    }) {
                        Text("取消")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        commitMessage = "Update \(fileName)"
                        showCommitDialog = true
                    }) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("提交修改")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.black)
                    .cornerRadius(8)
                    .disabled(!hasChanges || isSaving)
                    .opacity((!hasChanges || isSaving) ? 0.5 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            // 代码显示/编辑区
            if isEditing {
                TextEditor(text: $codeText)
                    .font(.system(size: fontSize, design: .monospaced))
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .padding(4)
            } else {
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        if showLineNumbers {
                            lineNumbers
                        }
                        Text(codeText)
                            .font(.system(size: fontSize, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, showLineNumbers ? 8 : 12)
                            .padding(.trailing, 12)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // 行号
    private var lineNumbers: some View {
        let lines = codeText.components(separatedBy: .newlines)
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<lines.count, id: \.self) { index in
                Text("\(index + 1)")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(height: fontSize * 1.5)
                    .padding(.trailing, 8)
            }
        }
        .padding(.leading, 12)
        .background(Color(.systemGray6))
    }
    
    private var hasChanges: Bool {
        return codeText != originalContent
    }
    
    private func loadFile() {
        isLoading = true
        errorMessage = nil
        
        GitHubAPI.shared.getFileContent(owner: owner, repo: repo, path: path, branch: branch) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let file):
                    fileContent = file
                    codeText = file.decodedContent
                    originalContent = codeText
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func commitChanges() {
        guard let sha = fileContent?.sha else { return }
        guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            commitMessage = "Update \(fileName)"
            return
        }
        
        isSaving = true
        
        GitHubAPI.shared.updateFile(
            owner: owner,
            repo: repo,
            path: path,
            content: codeText,
            sha: sha,
            message: commitMessage,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    showSaveSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        CodeEditorView(
            owner: "test",
            repo: "test",
            path: "README.md",
            branch: "main",
            fileName: "README.md"
        )
    }
}
