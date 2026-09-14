import SwiftUI

struct CodeEditorView: View {
    let owner: String
    let repo: String
    let path: String
    let branch: String
    let fileName: String
    // 是否自动进入编辑模式（用于contextMenu中"编辑文件"跳转）
    var autoEnterEditMode: Bool = false
    // 初始搜索关键词（用于从代码搜索结果跳转时自动定位）
    var initialSearchText: String = ""
    // 初始跳转到指定行（用于从代码搜索结果跳转时快速定位，不使用编辑器内部搜索功能）
    var initialLineNumber: Int? = nil

    // 用于退出页面
    @Environment(\.dismiss) private var dismiss

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
    @State private var fontSize: CGFloat = 10
    @State private var showSettings: Bool = false
    @State private var showRenameDialog: Bool = false
    @State private var newFileName: String = ""
    @State private var isRenaming: Bool = false
    @State private var showRenameSuccess: Bool = false
    @State private var renameErrorMessage: String?
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var showCopySuccess: Bool = false
    @State private var lastCommitInfo: Commit?

    // 未保存提醒状态
    @State private var showUnsavedAlert: Bool = false
    // 标记是否保存后自动退出（从"未保存提醒"弹窗点击"保存并离开"时设置）
    @State private var shouldDismissAfterSave: Bool = false
    // 编辑模式下点击返回的提示
    @State private var editReturnAlert: Bool = false

    // 查找相关状态
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    // 滚动到指定行（用于从代码搜索结果跳转时快速定位）
    @State private var scrollTargetLine: Int? = nil

    // 选中文字查找相关状态
    @State private var getSelectedTextTrigger: Int = 0
    @State private var showNoSelectionAlert: Bool = false
    @State private var waitingForSelectedText: Bool = false

    // 二次确认状态
    @State private var showCancelConfirm: Bool = false
    @State private var showSubmitConfirm: Bool = false

    // 图片预览相关状态
    @State private var previewImage: UIImage?
    @State private var isLoadingImage: Bool = false
    @State private var imageLoadError: String?
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    // 图片加载任务，用于在页面消失时取消
    @State private var imageLoadTask: URLSessionDataTask?

    // 键盘管理器（统一管理键盘状态，彻底解决键盘跟随问题）
    @ObservedObject private var keyboardManager = KeyboardManager.shared

    // 撤销/重做管理器（第二期：编辑体验增强）
    @ObservedObject private var undoManager = EditorUndoManager.shared
    // 撤销/重做可用状态（由CodeTextView回调更新）
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    // 草稿管理器（第二期：编辑体验增强）
    @ObservedObject private var draftManager = DraftManager.shared

    // 代码片段管理器（第二期：编辑体验增强）
    @ObservedObject private var snippetManager = CodeSnippetManager.shared

    // 代码片段弹窗显示状态
    @State private var showSnippetPicker: Bool = false

    // 符号导航器（第三期：高级编辑功能）
    @StateObject private var symbolNavigator = SymbolNavigator()

    // 符号导航弹窗显示状态
    @State private var showSymbolPicker: Bool = false

    // 编辑器主题管理器（第四期：协作与生产力）
    @ObservedObject private var themeManager = EditorThemeManager.shared

    // 主题选择弹窗显示状态
    @State private var showThemePicker: Bool = false

    // MARK: - 大文件降级模式（性能优化与崩溃防护）
    // 大文件模式：>5MB，禁用编辑，只读快速浏览
    @State private var isLargeFileMode: Bool = false
    // 超大文件模式：>20MB，禁用语法高亮，纯文本显示
    @State private var isUltraLargeFileMode: Bool = false
    // 文件大小显示（格式化后的字符串）
    @State private var fileSizeDisplay: String = ""

    // 大文件阈值常量
    private let largeFileThreshold: Int = 5 * 1024 * 1024 // 5MB
    private let ultraLargeFileThreshold: Int = 20 * 1024 * 1024 // 20MB

    var body: some View {
        VStack(spacing: 0) {
            contentView
            // 编辑模式底部工具栏放在VStack中，自动跟随键盘移动
            if isEditing && (fileContent?.isTextFile ?? false) {
                editModeBottomBar
            }
        }
        // 使用系统自动键盘避让，UITextView会自动调整contentInset
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        // 隐藏系统默认返回按钮，使用自定义返回按钮实现编辑保护
        .navigationBarBackButtonHidden(false)
        // 编辑模式下禁用手势返回
        .gesture(
            DragGesture()
                .onEnded { value in
                    if isEditing && value.translation.width > 50 {
                        editReturnAlert = true
                    }
                }
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // 文件操作
                    Button(action: {
                        showRenameDialog = true
                        newFileName = fileName
                    }) {
                        Label("重命名文件", systemImage: "pencil")
                    }

                    Button(action: {
                        copyFilePath()
                    }) {
                        Label("复制文件路径", systemImage: "doc.on.doc")
                    }

                    Button(action: {
                        downloadFile()
                    }) {
                        Label("下载该文件", systemImage: "square.and.arrow.down")
                    }

                    Divider()

                    if fileContent?.isTextFile ?? false {
                        Button(action: {
                            showSearch.toggle()
                            if !showSearch {
                                searchText = ""
                                currentMatchIndex = 0
                                totalMatches = 0
                            }
                        }) {
                            Label(showSearch ? "关闭查找" : "查找", systemImage: "magnifyingglass")
                        }

                        Button(action: {
                            isEditing.toggle()
                        }) {
                            Label(isEditing ? "完成编辑" : "编辑文件", systemImage: isEditing ? "checkmark" : "pencil")
                        }
                        .disabled(isLargeFileMode) // 大文件模式下禁用编辑

                        Button(action: {
                            UIPasteboard.general.string = codeText
                        }) {
                            Label("复制全部内容", systemImage: "doc.on.doc")
                        }

                        // 代码片段（第二期：编辑体验增强）
                        Button(action: {
                            showSnippetPicker = true
                        }) {
                            Label("代码片段", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        .disabled(!isEditing)

                        // 符号导航（第三期：高级编辑功能）
                        Button(action: {
                            showSymbolPicker = true
                        }) {
                            Label("符号导航", systemImage: "list.bullet.indent")
                        }

                        // 编辑器主题（第四期：协作与生产力）
                        Button(action: {
                            showThemePicker = true
                        }) {
                            Label("编辑器主题", systemImage: "paintpalette")
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

                        Divider()
                    }

                    if let htmlUrl = fileContent?.htmlUrl {
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
                .disabled(isRenaming || isDownloading)
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
                // 如果是从"未保存提醒"弹窗点击"保存并离开"触发的提交，提交成功后自动退出
                if shouldDismissAfterSave {
                    shouldDismissAfterSave = false
                    dismiss()
                } else {
                    isEditing = false
                    loadFile()
                }
            }
        } message: {
            Text("文件已成功提交到 GitHub 仓库")
        }
        .alert("重命名文件", isPresented: $showRenameDialog) {
            TextField("新文件名", text: $newFileName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                renameFile()
            }
            .disabled(newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("当前文件名: \(fileName)\n请输入新的文件名")
        }
        .alert("重命名成功", isPresented: $showRenameSuccess) {
            Button("确定") {
                // 返回上一页
                NotificationCenter.default.post(name: NSNotification.Name("FileRenamed"), object: nil)
            }
        } message: {
            Text("文件已成功重命名")
        }
        .alert("重命名失败", isPresented: .constant(renameErrorMessage != nil)) {
            Button("确定") {
                renameErrorMessage = nil
            }
        } message: {
            Text(renameErrorMessage ?? "未知错误")
        }
        .alert("复制成功", isPresented: $showCopySuccess) {
            Button("确定") {}
        } message: {
            Text("文件 Raw 地址已复制到剪贴板")
        }
        .alert("未选中文字", isPresented: $showNoSelectionAlert) {
            Button("确定") {}
        } message: {
            Text("请先在代码中选中要查找的文字，然后再点击「查找选中文字」")
        }
        // 未保存提醒弹窗
        .alert("文件未保存", isPresented: $showUnsavedAlert) {
            // 保存按钮（蓝色）
            Button(action: {
                // 标记保存后自动退出
                shouldDismissAfterSave = true
                // 先提交修改，提交成功后退出
                showCommitDialog = true
                showUnsavedAlert = false
            }) {
                Text("保存并离开")
                    .foregroundColor(.blue)
            }
            // 不保存按钮（红色）
            Button(role: .destructive) {
                // 直接退出，不保存
                dismiss()
            } label: {
                Text("不保存，直接离开")
                    .foregroundColor(.red)
            }
            // 取消按钮
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前文件有未保存的修改，确定要离开吗？")
        }
        // 编辑模式下点击返回的提示
        .alert("正在编辑中", isPresented: $editReturnAlert) {
            Button("确定") {}
        } message: {
            Text("正在编辑文件，请先完成编辑或点击「完成编辑」后再返回")
        }
        // 取消编辑二次确认
        .alert("确认取消", isPresented: $showCancelConfirm) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃修改", role: .destructive) {
                codeText = originalContent
                isEditing = false
            }
        } message: {
            Text("您有未保存的修改，确定要放弃吗？")
        }
        // 提交修改二次确认
        .alert("确认提交", isPresented: $showSubmitConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认提交") {
                commitMessage = "Update \(fileName)"
                showCommitDialog = true
            }
        } message: {
            Text("确定要提交修改到 GitHub 仓库吗？")
        }
        .overlay {
            if isDownloading {
                downloadProgressOverlay
            }
        }
        .onAppear {
            loadFile()

            // 键盘状态由KeyboardManager统一管理，无需本地监听
            // 进入前台时重置键盘状态，避免状态残留
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                // 进入前台时重置键盘管理器状态
                KeyboardManager.shared.reset()
            }
        }
        // 页面消失时强制恢复TabBar显示，防止编辑模式下返回导致TabBar一直隐藏
        .onDisappear {
            // 移除应用进入前台监听
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)

            // 重置键盘管理器状态，避免状态残留
            KeyboardManager.shared.reset()

            // 结束草稿编辑（自动保存未保存的草稿）
            draftManager.endEditing()

            // 取消正在进行的图片加载任务，避免回调访问已销毁的视图
            imageLoadTask?.cancel()
            imageLoadTask = nil

            // 清理图片相关状态，释放内存
            previewImage = nil
            isLoadingImage = false
            imageLoadError = nil

            // 延迟一帧执行，确保视图层级还在
            DispatchQueue.main.async {
                // 递归查找并恢复TabBar显示
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    var responder: UIResponder? = window.rootViewController
                    while let next = responder {
                        if let tabBarController = next as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                            break
                        }
                        responder = next.next
                    }
                }
            }
        }
        // 监听编辑模式变化，确保手势和Tab栏状态立即更新
        .onChange(of: isEditing) { _ in
            // 强制刷新SwipeBackControlView和TabBarControlView
            // UIViewRepresentable的updateUIView会自动调用
        }
        // 监听文本变化，自动更新草稿（第二期：编辑体验增强）
        .onChange(of: codeText) { _ in
            if isEditing {
                draftManager.updateDraftContent(codeText)
            }
        }
        // 编辑模式时禁用手势返回
        .background(SwipeBackControlView(enabled: !isEditing))
        // 编辑模式时隐藏底部Tab栏，禁止切换到"我的"等页面
        .background(TabBarControlView(visible: !isEditing))
        // 代码片段选择弹窗（第二期：编辑体验增强）
        .sheet(isPresented: $showSnippetPicker) {
            snippetPickerView
        }
        // 符号导航弹窗（第三期：高级编辑功能）
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(symbolNavigator: symbolNavigator) { symbol in
                // 跳转到符号所在行
                scrollTargetLine = symbol.lineNumber
                showSymbolPicker = false
            }
        }
        // 主题选择弹窗（第四期：协作与生产力）
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView { theme in
                themeManager.switchTheme(theme)
                showThemePicker = false
            }
        }
    }

    // MARK: - 下载进度覆盖层

    private var downloadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.blue)
                    .frame(width: 70, height: 70)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                    .background(Color.white)
                    .cornerRadius(35)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑

                Text("正在下载文件")
                    .font(.headline)
                    .foregroundColor(.black)

                Text(fileName)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .frame(maxWidth: 250)

                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 250)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

                Text(String(format: "%.0f%%", downloadProgress * 100))
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
            .padding(32)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
            .background(Color.white)
            .cornerRadius(20)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            .shadow(radius: 20)
        }
    }

    // MARK: - 代码片段选择器（第二期：编辑体验增强）

    private var snippetPickerView: some View {
        NavigationView {
            List {
                ForEach(snippetManager.getSnippets(for: fileContent?.fileExtension ?? "")) { snippet in
                    Button(action: {
                        // 插入代码片段到当前位置
                        insertSnippet(snippet)
                        showSnippetPicker = false
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(snippet.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(snippet.trigger)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            Text(snippet.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(snippet.code)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("代码片段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showSnippetPicker = false
                    }
                }
            }
        }
    }

    /// 插入代码片段到当前光标位置
    private func insertSnippet(_ snippet: CodeSnippetManager.Snippet) {
        let result = snippetManager.expandSnippet(snippet)
        // 简单实现：将代码片段追加到文本末尾
        // 实际应用中应该插入到光标位置，这里简化处理
        codeText += result.code
        // hasChanges是计算属性，通过codeText != originalContent自动判断，无需手动设置
    }

    // MARK: - 编辑模式底部工具栏

    private var editModeBottomBar: some View {
        HStack(spacing: 8) {
            // 撤销按钮
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("CodeEditorUndo"), object: nil)
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundColor(canUndo ? .blue : .gray)
                    .frame(width: 40, height: 44)  // 这是视图宽高尺寸，控制按钮水平和垂直方向显示大小，单位是pt；改大按钮更大更易点击，改小按钮更小更紧凑；还能改成.maxWidth/.maxHeight占满父视图
            }
            .disabled(!canUndo)

            // 重做按钮
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("CodeEditorRedo"), object: nil)
            }) {
                Image(systemName: "arrow.uturn.forward")
                    .foregroundColor(canRedo ? .blue : .gray)
                    .frame(width: 40, height: 44)  // 这是视图宽高尺寸，控制按钮水平和垂直方向显示大小，单位是pt；改大按钮更大更易点击，改小按钮更小更紧凑；还能改成.maxWidth/.maxHeight占满父视图
            }
            .disabled(!canRedo)

            // 取消按钮
            Button(action: {
                // 取消按钮二次确认
                if hasChanges {
                    showCancelConfirm = true
                } else {
                    // 没有修改，直接取消
                    codeText = originalContent
                    isEditing = false
                }
            }) {
                Text("取消")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)  // 这是视图高度尺寸，控制组件垂直方向显示高度，单位是pt；改大组件纵向更高，改小组件纵向更矮；还能改成.maxHeight: .infinity占满父视图或用.minHeight设最小高度
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }

            // 提交修改按钮
            Button(action: {
                // 提交修改按钮二次确认
                showSubmitConfirm = true
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
            .frame(height: 44)  // 这是视图高度尺寸，控制组件垂直方向显示高度，单位是pt；改大组件纵向更高，改小组件纵向更矮；还能改成.maxHeight: .infinity占满父视图或用.minHeight设最小高度
            .background(Color.black)
            .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            .disabled(!hasChanges || isSaving)
            .opacity((!hasChanges || isSaving) ? 0.5 : 1)
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - 文件信息栏

    private var fileInfoBar: some View {
        HStack(spacing: 12) {
            // 文件大小
            if let content = fileContent {
                Label(content.size.formattedFileSize, systemImage: "doc")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 大文件模式提示（性能优化与崩溃防护）
            if isUltraLargeFileMode {
                Label("超大文件·纯文本模式", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if isLargeFileMode {
                Label("大文件·只读模式", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            Spacer()

            // 最后编辑时间
            if let commit = lastCommitInfo {
                Label(commit.commit.committer.relativeDate, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Label("加载中...", systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
    }

    // MARK: - 内容区域（拆分复杂表达式，解决编译器类型检查超时）

    private var contentView: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error: error)
            } else if let content = fileContent {
                if content.isImageFile {
                    // 图片文件：显示图片预览
                    imagePreviewView(content: content)
                } else if !content.isTextFile {
                    // 其他二进制文件：显示二进制文件提示
                    binaryFileView(content: content)
                } else {
                    // 文本文件：显示代码编辑器
                    codeEditorArea
                }
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("加载文件中...")
            Spacer()
        }
    }

    private func errorView(error: String) -> some View {
        VStack {
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
        }
    }

    private func binaryFileView(content: FileContent) -> some View {
        VStack {
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
        }
    }

    // MARK: - 图片预览区域

    private func imagePreviewView(content: FileContent) -> some View {
        GeometryReader { geometry in
            ZStack {
                if isLoadingImage {
                    // 加载中
                    VStack(spacing: 16) {
                        ProgressView("加载图片中...")
                        Text(fileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = imageLoadError {
                    // 加载失败
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            loadImage(from: content.downloadUrl)
                        }
                        .buttonStyle(.bordered)
                        if let downloadUrl = content.downloadUrl {
                            Button("下载文件") {
                                if let url = URL(string: downloadUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let image = previewImage {
                    // 图片预览（支持缩放和平移）
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width * imageScale, height: geometry.size.height * imageScale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        imageScale = max(1.0, min(5.0, value))
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // 双击重置缩放
                    .onTapGesture(count: 2) {
                        withAnimation {
                            imageScale = 1.0
                        }
                    }
                }
            }
            .onAppear {
                // 视图出现时加载图片
                if previewImage == nil && !isLoadingImage {
                    loadImage(from: content.downloadUrl)
                }
            }
        }
    }

    /// 从URL加载图片
    private func loadImage(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            imageLoadError = "无效的图片地址"
            return
        }

        // 取消之前的加载任务
        imageLoadTask?.cancel()

        isLoadingImage = true
        imageLoadError = nil

        // 使用URLSession加载图片数据
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoadingImage = false
                self.imageLoadTask = nil

                if let error = error {
                    // 如果是取消错误，忽略
                    if (error as NSError).code == NSURLErrorCancelled {
                        return
                    }
                    self.imageLoadError = "加载失败: \(error.localizedDescription)"
                    return
                }

                guard let data = data, let image = UIImage(data: data) else {
                    self.imageLoadError = "图片数据无效或格式不支持"
                    return
                }

                self.previewImage = image
            }
        }
        imageLoadTask = task
        task.resume()
    }

    // MARK: - 代码编辑区域

    private var codeEditorArea: some View {
        VStack(spacing: 0) {
            // 文件信息栏（编辑模式下隐藏，让出更多代码区域空间）
            if !isEditing {
                fileInfoBar
            }

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
                .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                // 编辑模式提示条行高减少一半
                .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(Color.blue.opacity(0.1))
            }

            // 查找栏
            if showSearch {
                searchBar
            }

            // 代码显示/编辑区 - 使用高性能CodeTextView，基于原生UITextView
            CodeTextView(
                text: $codeText,
                isEditable: isEditing,
                showLineNumbers: showLineNumbers,
                fontSize: $fontSize,
                onTextChange: { _ in },
                fileName: fileName,
                onSearchResult: { current, total in
                    currentMatchIndex = current - 1
                    totalMatches = total
                },
                onLookupSelectedText: { selectedText in
                    // 选中文字后点击编辑菜单中的"🔍查找"，直接查找选中的文字
                    searchText = selectedText
                    currentMatchIndex = 0
                    showSearch = true
                },
                searchText: searchText,
                currentMatchIndex: currentMatchIndex,
                isSearchActive: showSearch && !searchText.isEmpty,
                getSelectedTextTrigger: getSelectedTextTrigger,
                onSelectedText: { selectedText in
                    // 获取到选中文字后，自动填入查找框并显示查找栏
                    waitingForSelectedText = false
                    searchText = selectedText
                    currentMatchIndex = 0
                    showSearch = true
                },
                scrollToLine: scrollTargetLine,
                // 撤销/重做状态更新回调
                onUndoRedoStateChange: { canUndo, canRedo in
                    self.canUndo = canUndo
                    self.canRedo = canRedo
                }
            )
            // 使用系统自动键盘避让，UITextView会自动调整contentInset，无需手动添加padding
        }
    }

    // MARK: - 选中文字查找

    private func searchSelectedText() {
        // 设置等待标志
        waitingForSelectedText = true

        // 递增触发器，触发CodeTextView获取选中文字
        getSelectedTextTrigger += 1

        // 延迟200ms检查是否有选中文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if waitingForSelectedText {
                // 没有选中文字，显示提示
                waitingForSelectedText = false
                showNoSelectionAlert = true
            }
        }
    }

    // MARK: - 查找栏

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("查找代码...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { _ in
                        currentMatchIndex = 0
                    }

                // 查找结果显示
                if totalMatches > 0 {
                    Text("\(currentMatchIndex + 1)/\(totalMatches)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 50)
                } else if !searchText.isEmpty {
                    Text("无结果")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(minWidth: 50)
                }
            }

            HStack(spacing: 12) {
                // 关闭查找（左侧，左手操作）
                Button(action: {
                    showSearch = false
                    searchText = ""
                    currentMatchIndex = 0
                    totalMatches = 0
                }) {
                    Text("完成")
                        .foregroundColor(.blue)
                        .frame(height: 36)  // 这是视图高度尺寸，控制组件垂直方向显示高度，单位是pt；改大组件纵向更高，改小组件纵向更矮；还能改成.maxHeight: .infinity占满父视图或用.minHeight设最小高度
                }

                Spacer()

                // 上一个（右侧，右手拇指操作）
                Button(action: {
                    if totalMatches > 0 {
                        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("上一个")
                            .font(.subheadline)
                        Image(systemName: "chevron.up")
                    }
                    .foregroundColor(.white)
                    .frame(width: 90, height: 36)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                    .background(totalMatches > 0 ? Color(red: 0.35, green: 0.6, blue: 1.0) : Color.gray.opacity(0.5))
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
                .disabled(totalMatches == 0)

                // 下一个（右侧，右手拇指操作）
                Button(action: {
                    if totalMatches > 0 {
                        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("下一个")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                    .foregroundColor(.white)
                    .frame(width: 90, height: 36)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                    .background(totalMatches > 0 ? Color(red: 0.35, green: 0.6, blue: 1.0) : Color.gray.opacity(0.5))
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
                .disabled(totalMatches == 0)
            }
        }
        .padding(.horizontal, 12)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
    }

    private var hasChanges: Bool {
        return codeText != originalContent
    }
    
    private func loadFile() {
        isLoading = true
        errorMessage = nil
        lastCommitInfo = nil

        GitHubAPI.shared.getFileContent(owner: owner, repo: repo, path: path, branch: branch) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let file):
                    fileContent = file
                    codeText = file.decodedContent
                    originalContent = codeText

                    // 初始化撤销/重做管理器（设置当前文件路径，隔离不同文件的撤销栈）
                    undoManager.setCurrentFile("\(owner)/\(repo)/\(branch)/\(path)")
                    undoManager.clear()

                    // 初始化草稿管理器
                    draftManager.startEditing(
                        filePath: path,
                        branch: branch,
                        content: codeText,
                        fileSha: file.sha
                    )

                    // 文件大小检测与降级策略（崩溃防护）
                    let fileSize = file.size
                    fileSizeDisplay = formatFileSize(fileSize)

                    if fileSize >= ultraLargeFileThreshold {
                        // 超大文件（>20MB）：禁用语法高亮，纯文本显示，禁用编辑
                        isUltraLargeFileMode = true
                        isLargeFileMode = true
                        isEditing = false
                    } else if fileSize >= largeFileThreshold {
                        // 大文件（>5MB）：禁用编辑，只读快速浏览
                        isLargeFileMode = true
                        isUltraLargeFileMode = false
                        isEditing = false
                    } else {
                        // 正常文件
                        isLargeFileMode = false
                        isUltraLargeFileMode = false
                    }

                    // 如果设置了自动进入编辑模式，则在文件加载成功后自动进入编辑状态
                    // 大文件模式下强制禁用编辑
                    if autoEnterEditMode && !isLargeFileMode {
                        isEditing = true
                    }

                    // 如果设置了初始搜索关键词，则自动激活搜索功能
                    if !initialSearchText.isEmpty {
                        searchText = initialSearchText
                        currentMatchIndex = 0
                        showSearch = true
                    }

                    // 如果设置了初始跳转到指定行，则延迟滚动到指定行（等待视图渲染完成）
                    if let line = initialLineNumber, line > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollTargetLine = line
                        }
                    }

                    // 获取文件最后编辑时间
                    loadLastCommit()

                    // 解析文件符号（第三期：高级编辑功能）
                    symbolNavigator.parseSymbols(in: codeText, language: file.fileExtension)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadLastCommit() {
        GitHubAPI.shared.getFileLastCommit(owner: owner, repo: repo, path: path, branch: branch) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let commit):
                    lastCommitInfo = commit
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - 文件大小格式化（性能优化辅助）

    /// 格式化文件大小为人类可读字符串
    /// - Parameter size: 文件大小（字节）
    /// - Returns: 格式化后的字符串
    private func formatFileSize(_ size: Int) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: Int64(size))
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
                    // 提交成功后更新原始内容
                    originalContent = codeText
                    // 清除撤销/重做栈
                    undoManager.clear()
                    // 清除草稿
                    draftManager.clearDraft(for: path, branch: branch)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 重命名文件

    private func renameFile() {
        let trimmedName = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            renameErrorMessage = "文件名不能为空"
            return
        }

        guard trimmedName != fileName else {
            renameErrorMessage = "新文件名与原文件名相同，请输入不同的文件名"
            return
        }

        isRenaming = true

        // 计算新路径
        let pathComponents = path.components(separatedBy: "/")
        var newPathComponents = pathComponents
        newPathComponents.removeLast()
        newPathComponents.append(trimmedName)
        let newPath = newPathComponents.joined(separator: "/")

        GitHubAPI.shared.renameFile(
            owner: owner,
            repo: repo,
            oldPath: path,
            newPath: newPath,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isRenaming = false
                switch result {
                case .success:
                    showRenameSuccess = true
                case .failure(let error):
                    renameErrorMessage = "重命名失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 复制文件Raw地址

    private func copyFilePath() {
        let rawUrl = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(path)"
        UIPasteboard.general.string = rawUrl
        showCopySuccess = true
    }

    // MARK: - 下载文件

    private func downloadFile() {
        guard let downloadUrl = fileContent?.downloadUrl else {
            renameErrorMessage = "该文件不支持下载"
            return
        }

        isDownloading = true
        downloadProgress = 0

        FileDownloadManager.shared.downloadAndShare(
            from: downloadUrl,
            fileName: fileName,
            progress: { progress in
                self.downloadProgress = progress
            }
        ) { result in
            DispatchQueue.main.async {
                self.isDownloading = false
                if case .failure(let error) = result {
                    self.renameErrorMessage = "下载失败: \(error.localizedDescription)"
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

// MARK: - 禁用手势返回的UIViewRepresentable

/// 用于控制导航控制器的侧滑返回手势
struct SwipeBackControlView: UIViewRepresentable {
    let enabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 立即更新手势状态，不使用async延迟
        // 递归查找当前视图控制器的navigationController
        var responder: UIResponder? = uiView
        while let next = responder?.next {
            if let viewController = next as? UIViewController,
               let navigationController = viewController.navigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = enabled
                // 如果是启用手势，同时重置delegate确保手势生效
                if enabled {
                    navigationController.interactivePopGestureRecognizer?.delegate = nil
                }
                return
            }
            responder = next
        }
    }
}

// MARK: - 控制Tab栏显示的UIViewRepresentable

/// 用于控制底部Tab栏的显示和隐藏（兼容iOS 15）
struct TabBarControlView: UIViewRepresentable {
    let visible: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 立即更新Tab栏状态，不使用async延迟
        // 递归查找当前视图控制器的tabBarController
        let tabBarController = findTabBarController(from: uiView)
        tabBarController?.tabBar.isHidden = !visible
        // 保存当前的tabBarController引用，用于在视图销毁时恢复
        context.coordinator.tabBarController = tabBarController
    }

    /// 递归查找当前视图控制器的tabBarController
    private func findTabBarController(from view: UIView) -> UITabBarController? {
        var responder: UIResponder? = view
        while let next = responder?.next {
            if let viewController = next as? UIViewController,
               let tabBarController = viewController.tabBarController {
                return tabBarController
            }
            responder = next
        }
        return nil
    }

    // MARK: - Coordinator

    class Coordinator {
        weak var tabBarController: UITabBarController?
        // 注意：不在deinit中执行任何操作，避免在对象销毁时访问self导致闪退
        // TabBar的恢复依赖CodeEditorView的onDisappear来完成
    }
}
