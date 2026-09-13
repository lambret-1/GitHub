# FileBrowser 文件浏览器模块

## 模块说明
本模块负责仓库文件的浏览、查看、编辑与操作，是GitHub客户端的核心功能模块，包含文件列表、代码查看、文件操作、仓库头部、分支管理、README展示等功能。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `FileBrowserView.swift` | 文件浏览器主视图，展示仓库文件列表，支持文件浏览、上传、下载、编辑、删除、分支切换、提交记录、Actions等功能 |
| `RepoHeaderView.swift` | 仓库头部组件，复刻GitHub网页仓库页顶部布局，展示仓库信息、Watch/Fork/Star按钮、描述、Topics、元信息等 |
| `BranchBarView.swift` | 分支栏组件，展示当前分支、分支切换、创建分支、重命名分支、删除分支等功能 |
| `CreateFileView.swift` | 新建文件视图，支持输入文件名、创建文件、创建成功后自动跳转到编辑状态 |
| `CreateFolderView.swift` | 创建文件夹视图，支持输入文件夹名、创建文件夹 |
| `DocumentPickerView.swift` | 文件选择器视图，基于UIDocumentPickerViewController封装，支持多选或单选文件、统一确认上传 |
| `HTMLPreviewView.swift` | HTML网页预览视图，基于WKWebView渲染HTML内容，支持刷新、加载进度、缓存机制 |
| `ReadmeView.swift` | README展示视图，获取Markdown原文并渲染展示，对齐GitHub官方样式 |

## 功能参数说明

### FileBrowserView 文件浏览器
- `repository: Repository` - 仓库对象，包含仓库信息
- 内部状态变量：
  - `currentPath: String` - 当前浏览的目录路径
  - `files: [FileItem]` - 当前目录下的文件和文件夹数组
  - `selectedBranch: String` - 当前选中的分支名
  - `isLoading: Bool` - 文件列表加载中状态
  - `isUploading: Bool` - 文件上传中状态
  - `isDownloading: Bool` - 文件下载中状态
  - `isDeleteMode: Bool` - 是否处于多选删除模式
  - `selectedFilesForDelete: [FileItem]` - 多选删除模式下选中的文件数组
  - `isStarred: Bool` - 仓库是否已星标
  - `isStarring: Bool` - 星标操作中状态
  - `localStarCount: Int?` - 本地星标数量，用于星标状态变化时实时更新

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

### BranchBarView 分支栏
- `branches: Binding<[Branch]>` - 分支列表绑定
- `selectedBranch: Binding<String>` - 当前选中分支绑定
- `onBranchChange: (String) -> Void` - 分支切换回调
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- `onBranchesChanged: () -> Void` - 分支列表变化回调

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
5. **文件上传**：支持多选或单选文件上传，统一确认上传
6. **文件下载**：支持下载单个文件、下载仓库ZIP
7. **文件编辑**：支持代码编辑、语法高亮、行号显示、保存提交
8. **文件删除**：支持多选删除模式、重按删除、二次确认
9. **新建文件/文件夹**：支持创建新文件和文件夹
10. **重命名**：支持重命名文件和文件夹
11. **复制路径**：支持复制文件Raw地址
12. **HTML预览**：支持预览HTML文件，带刷新功能
13. **README展示**：获取Markdown原文并渲染，对齐GitHub官方样式
14. **仓库头部**：复刻GitHub官方布局，展示仓库信息、Watch/Fork/Star按钮
15. **星标功能**：支持星标/取消星标，带动画效果和数量实时更新
16. **Fork功能**：支持Fork仓库，带二次确认
17. **提交记录**：查看仓库提交历史
18. **Actions**：查看仓库Actions工作流
19. **Issues/PR**：查看仓库Issues和Pull Requests
20. **仓库设置**：查看仓库设置和统计信息
21. **下拉刷新**：支持下拉刷新文件列表
22. **左滑手势**：支持左滑返回上级目录
23. **深色模式适配**：所有视图适配深色模式
24. **操作提示**：操作成功/失败显示Toast提示
