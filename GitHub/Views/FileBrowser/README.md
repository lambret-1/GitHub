# FileBrowser 文件浏览器模块

## 模块说明
本模块负责仓库文件的浏览、查看、编辑与操作，是GitHub客户端的核心功能模块，包含文件列表、代码查看、文件操作、仓库头部、分支管理、README展示等功能。星标功能全新优化，支持动画效果和数量实时更新。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `FileBrowserView.swift` | 文件浏览器主视图，展示仓库文件列表，支持文件浏览、上传、下载、编辑、删除、分支切换、提交记录、Actions、星标/Fork等功能 |
| `RepoHeaderView.swift` | 仓库头部组件，复刻GitHub网页仓库页顶部布局，展示仓库信息、Watch/Fork/Star按钮（带动画效果）、描述、Topics、元信息等 |
| `BranchBarView.swift` | 分支栏组件，展示当前分支、分支切换、创建分支、重命名分支、删除分支、标签切换等功能 |
| `TagListView.swift` | 标签列表选择页，展示仓库所有Git标签，支持搜索、选中切换到该标签版本、空态/错误态/加载态 |
| `CreateFileView.swift` | 新建文件视图，支持输入文件名、创建文件、创建成功后自动跳转到编辑状态 |
| `CreateFolderView.swift` | 创建文件夹视图，支持输入文件夹名、创建文件夹 |
| `DocumentPickerView.swift` | 文件选择器视图，基于UIDocumentPickerViewController封装，支持多选或单选文件、统一确认上传 |
| `HTMLPreviewView.swift` | HTML网页预览视图，基于WKWebView渲染HTML内容，支持刷新、加载进度、缓存机制 |
| `ReadmeView.swift` | README展示视图，获取Markdown原文并渲染展示，对齐GitHub官方样式 |

## 功能参数说明

### FileBrowserView 文件浏览器
- `repository: Repository` - 仓库对象，包含仓库信息
- 内部状态变量（核心）：
  - `currentPath: String` - 当前浏览的目录路径
  - `files: [FileItem]` - 当前目录下的文件和文件夹数组
  - `selectedBranch: String` - 当前选中的分支名
  - `isLoading: Bool` - 文件列表加载中状态
  - `isUploading: Bool` - 文件上传中状态
  - `isDownloading: Bool` - 文件下载中状态
  - `isDeleteMode: Bool` - 是否处于多选删除模式
  - `selectedFilesForDelete: [FileItem]` - 多选删除模式下选中的文件数组
  - `isStarred: Bool` - 仓库是否已星标
  - `isCheckingStar: Bool` - 检查星标状态中
  - `isStarring: Bool` - 星标操作中状态
  - `isForking: Bool` - Fork操作中状态
  - `localStarCount: Int?` - 本地星标数量，用于星标状态变化时实时更新
  - `showOperationMessage: Bool` - 是否显示操作提示
  - `operationMessage: String` - 操作提示信息
  - `selectedTab: RepoTab` - 当前选中的Tab（code/issues/pullRequests/actions/settings）
  - `showCommits: Bool` - 是否显示提交记录页面
  - `showActions: Bool` - 是否显示Actions页面
- 核心函数：
  - `checkStarredStatus()` - 检查仓库是否已被星标（修复P0：所有仓库都检查，包括自己的仓库）
  - `toggleStar()` - 切换星标状态
  - `starRepository()` - 星标仓库（成功后localStarCount+1）
  - `unstarRepository()` - 取消星标仓库（成功后localStarCount-1）
  - `forkRepository()` - Fork仓库
  - `copyRepositoryURL()` - 复制仓库网页地址到剪贴板
  - `copyRepositoryHTTPSURL()` - 复制仓库HTTPS克隆链接到剪贴板
  - `copyRepositorySSHURL()` - 复制仓库SSH克隆链接到剪贴板
  - `showMessage(_:)` - 显示操作提示Toast
  - `loadFiles()` - 加载文件列表
  - `loadBranches()` - 加载分支列表
  - `navigateUp()` - 返回上级目录

### RepoHeaderView 仓库头部
- `repository: Repository` - 仓库对象
- `isStarred: Bool` - 是否已星标
- `isCheckingStar: Bool` - 检查星标状态中
- `isStarring: Bool` - 星标操作中
- `isForking: Bool` - Fork操作中
- `onToggleStar: () -> Void` - 切换星标回调
- `onFork: () -> Void` - Fork仓库回调
- `starCount: Int?` - 星标数量（可选，用于实时更新）
- `onViewParent: ((RepositoryParent) -> Void)?` - 查看父仓库回调
- 内部状态：
  - `isDescriptionExpanded: Bool` - 描述是否展开
- 星标按钮动画效果：
  - 点击时spring缩放动画
  - 星标图标缩放动画（星标时放大1.2倍）
  - 背景颜色过渡动画（星标时黄色背景）
  - 边框颜色过渡动画（星标时黄色边框）
  - 按钮点击时缩放反馈

### BranchBarView 分支栏
- `branches: Binding<[Branch]>` - 分支列表绑定
- `selectedBranch: Binding<String>` - 当前选中分支绑定（选中标签时也存标签名）
- `onBranchChange: (String) -> Void` - 分支切换回调
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- `onBranchesChanged: () -> Void` - 分支列表变化回调
- `tags: [GitTag]` - 标签列表（用于判断当前是否标签视图）
- `onTagSelected: (String) -> Void` - 标签选中回调
- `menuContent: () -> MenuContent` - 代码操作菜单内容（泛型）
- 布局：左侧分支选择按钮 + 标签选择按钮，右侧代码操作下拉按钮
- 标签视图时标签按钮蓝色高亮，显示当前标签名
- 代码操作按钮（修复P0）：
  - 文字为「代码操作」，箭头在右侧
  - 绿色背景，对齐GitHub官方品牌色
  - 点击弹出下拉菜单，包含：复制HTTPS链接、复制SSH链接、提交记录、Actions、下载仓库ZIP、在GitHub打开

### TagListView 标签列表选择页
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- `当前选中Ref: Binding<String>` - 当前选中的ref（分支名或标签名）
- `onTagSelected: (String) -> Void` - 标签选中回调
- 独立全屏页（fullScreenCover），自带NavigationView，左上角返回按钮
- 顶部搜索框，实时过滤标签名
- 列表每行：标签图标 + 标签名 + commit短码（7位）+ 选中标记
- 空态："该仓库暂无标签"
- 加载态：ProgressView
- 错误态：错误信息 + 重试按钮
- 选中标签后自动关闭页面并回调

### CreateFileView 新建文件
- 内部状态：`newFileName: String` - 新文件名
- 创建成功后自动跳转到编辑状态

### CreateFolderView 创建文件夹
- 内部状态：`newFolderName: String` - 新文件夹名

### DocumentPickerView 文件选择器
- 基于UIDocumentPickerViewController封装
- 支持多选或单选文件
- 选择文件后自动跳过确认步骤，最后统一确认上传

### HTMLPreviewView HTML预览
- `htmlContent: String` - HTML内容
- `title: String` - 页面标题
- 基于WKWebView渲染
- 顶部工具栏左侧刷新按钮
- 加载进度提示
- 缓存机制

### ReadmeView README展示
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- `branch: String` - 分支名称
- 获取Markdown原文并渲染展示

## 核心功能
1. **文件列表展示**：文件/文件夹图标、文件名、文件大小、最后编辑时间（相对时间）
2. **文件浏览**：点击文件打开（代码编辑器或HTML预览），点击文件夹进入文件夹
3. **路径导航**：面包屑路径导航，支持点击返回上级目录
4. **分支管理**：切换分支、创建分支、重命名分支、删除分支
5. **标签管理**：查看仓库所有Git标签，支持搜索筛选，选中标签后切换文件浏览到该标签版本；标签视图下所有写操作（新建/编辑/删除/上传/重命名）自动置灰只读，提示"标签为只读快照"
5. **文件上传**：支持多选或单选文件上传，统一确认上传
6. **文件下载**：支持下载单个文件、下载仓库ZIP
7. **文件编辑**：支持代码编辑、语法高亮、行号显示、保存提交
8. **文件删除**：支持多选删除模式、重按删除、二次确认
9. **新建文件/文件夹**：支持创建新文件和文件夹
10. **重命名**：支持重命名文件和文件夹
11. **复制路径**：支持复制文件Raw地址
12. **HTML预览**：支持预览HTML文件，带刷新功能
13. **README展示**：获取Markdown原文并渲染，对齐GitHub官方样式
14. **仓库头部**：复刻GitHub官方布局，展示仓库信息、Watch/Fork/Star按钮（修复P0：Fork图标更换为arrowshape.turn.up.right，避免小尺寸渲染异常）
15. **星标功能**：支持星标/取消星标，带动画效果（spring缩放、颜色过渡）和数量实时更新（修复P0：自己的仓库也检查星标状态，已星标显示填充黄星+黄色背景+「已标星」文字）
16. **代码操作菜单**：绿色「代码操作 ▾」按钮（修复P0：文字从「代码」改为「代码操作」，箭头移到右侧），包含复制HTTPS链接、复制SSH链接、提交记录、Actions、下载仓库ZIP、在GitHub打开
17. **复制链接**：支持复制仓库网页地址、HTTPS克隆链接、SSH克隆链接到剪贴板
18. **最新提交栏**：单行布局（修复P1：从两行压缩为单行），包含提交者头像、名称、提交信息、短哈希（可点击复制）、相对时间、查看历史按钮，整行可点击跳转提交历史
19. **Fork功能**：支持Fork仓库，带二次确认
20. **提交记录**：查看仓库提交历史
21. **Actions**：查看仓库Actions工作流
22. **Issues/PR**：查看仓库Issues和Pull Requests
23. **仓库设置**：查看仓库设置和统计信息
24. **下拉刷新**：支持下拉刷新文件列表
25. **左滑手势**：支持左滑返回上级目录
26. **深色模式适配**：所有视图适配深色模式
27. **操作提示**：操作成功/失败显示Toast提示

## 依赖模块
- `GitHub/Models/Repository.swift` - 仓库数据模型
- `GitHub/Models/FileItem.swift` - 文件项数据模型
- `GitHub/Models/Branch.swift` - 分支数据模型（在Workflow.swift中）
- `GitHub/Models/GitTag.swift` - Git标签数据模型
- `GitHub/Core/Network/GitHubAPI.swift` - GitHub API网络请求
- `GitHub/Core/Utils/AppState.swift` - 应用全局状态
- `GitHub/Core/Utils/FileDownloadManager.swift` - 文件下载管理
- `GitHub/Views/CodeEditor/CodeEditorView.swift` - 代码编辑器
- `GitHub/Views/Commits/CommitsListView.swift` - 提交记录列表
- `GitHub/Views/Actions/ActionsListView.swift` - Actions列表
