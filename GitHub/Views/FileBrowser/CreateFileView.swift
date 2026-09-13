import SwiftUI

// ==============================================================================
// CreateFileView 新建文件视图
// 功能：输入文件名，创建空文件，替代alert对话框确保按钮正常显示
// ==============================================================================

struct CreateFileView: View {
    let currentPath: String
    @State private var fileName: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    @EnvironmentObject private var appState: AppState
    var onCreate: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 提示信息
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                    Text("新建文件")
                        .font(.headline)
                    Text("将在 \(currentPath.isEmpty ? "根目录" : currentPath) 下创建空文件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .padding(.horizontal)

                Divider()

                // 文件名输入区域
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文件名")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("例如：test.swift", text: $fileName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.done)
                            .onSubmit {
                                createFile()
                            }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 16)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧

                Spacer()

                // 底部按钮区域
                VStack(spacing: 12) {
                    Button(action: {
                        createFile()
                    }) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text(isCreating ? "创建中..." : "创建文件")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .background(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    }
                    .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)

                    Button(action: {
                        onCancel()
                    }) {
                        Text("取消")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(10)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    }
                    .disabled(isCreating)
                }
                .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.bottom, 20)  // 这是底部内边距，控制内容下方与边缘的空白距离，单位是pt；改大下方留白更宽，改小下方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边
            }
            .navigationBarHidden(true)
            // 确保sheet正确继承暗黑模式颜色方案
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        }
    }

    private func createFile() {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFileName.isEmpty else {
            errorMessage = "文件名不能为空"
            return
        }

        // 检查文件名是否包含非法字符
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        if trimmedFileName.rangeOfCharacter(from: invalidCharacters) != nil {
            errorMessage = "文件名不能包含 / \\ ? % * | \" < > : 等字符"
            return
        }

        isCreating = true
        errorMessage = nil
        onCreate(trimmedFileName)
    }
}
