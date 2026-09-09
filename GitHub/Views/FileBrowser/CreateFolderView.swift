import SwiftUI

// ==============================================================================
// CreateFolderView 新建文件夹视图
// 功能：输入文件夹名称，创建文件夹，替代alert对话框确保按钮正常显示
// ==============================================================================

struct CreateFolderView: View {
    let currentPath: String
    @State private var folderName: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    var onCreate: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 提示信息
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    Text("创建文件夹")
                        .font(.headline)
                    Text("将在 \(currentPath.isEmpty ? "根目录" : currentPath) 下创建文件夹")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
                .padding(.horizontal)

                Divider()

                // 文件夹名输入区域
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文件夹名称")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("例如：MyFolder", text: $folderName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.done)
                            .onSubmit {
                                createFolder()
                            }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                Spacer()

                // 底部按钮区域
                VStack(spacing: 12) {
                    Button(action: {
                        createFolder()
                    }) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text(isCreating ? "创建中..." : "创建文件夹")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)

                    Button(action: {
                        onCancel()
                    }) {
                        Text("取消")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .disabled(isCreating)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }

    private func createFolder() {
        let trimmedFolderName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFolderName.isEmpty else {
            errorMessage = "文件夹名称不能为空"
            return
        }

        // 检查文件夹名是否包含非法字符
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        if trimmedFolderName.rangeOfCharacter(from: invalidCharacters) != nil {
            errorMessage = "文件夹名称不能包含 / \\ ? % * | \" < > : 等字符"
            return
        }

        isCreating = true
        errorMessage = nil
        onCreate(trimmedFolderName)
    }
}
