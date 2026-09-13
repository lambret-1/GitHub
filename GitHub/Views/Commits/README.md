# Commits 提交记录模块

## 模块说明
本模块负责GitHub仓库提交记录的展示与详情查看，包含提交列表、提交详情、文件Diff对比等功能。全新重构，对齐GitHub官方样式，支持大文件流畅渲染。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `CommitsListView.swift` | 提交记录列表视图，展示仓库的提交历史，支持下拉刷新、无限滚动加载更多、点击跳转详情、短哈希复制带视觉反馈 |
| `CommitDetailView.swift` | 提交详情视图，展示提交信息、作者、变更统计、变更文件列表，支持查看文件Diff、完整哈希复制 |

## 功能参数说明

### CommitsListView 提交列表
- `owner: String` - 仓库所有者用户名
- `repo: String` - 仓库名称
- `branch: String?` - 分支名称（可选，为空时使用默认分支）
- 内部状态：
  - `commits: [Commit]` - 提交列表数组
  - `isLoading: Bool` - 加载中状态
  - `errorMessage: String?` - 错误信息
  - `currentPage: Int` - 当前页码
  - `hasMore: Bool` - 是否有更多数据
  - `isLoadingMore: Bool` - 加载更多中状态
  - `selectedCommit: Commit?` - 选中的提交（用于跳转详情）
  - `operationMessage: String` - 操作提示信息
  - `showOperationMessage: Bool` - 是否显示操作提示

### CommitDetailView 提交详情
- `owner: String` - 仓库所有者用户名
- `repo: String` - 仓库名称
- `commit: Commit` - 提交对象，包含提交信息、作者、哈希等
- 内部状态：
  - `changedFiles: [ChangedFile]` - 变更文件列表
  - `isLoadingFiles: Bool` - 变更文件加载中状态
  - `filesError: String?` - 变更文件错误信息
  - `selectedFile: ChangedFile?` - 选中的文件（用于查看Diff）
  - `operationMessage: String` - 操作提示信息
  - `showOperationMessage: Bool` - 是否显示操作提示

### CommitRow 提交行（CommitsListView内定义）
- `commit: Commit` - 提交对象
- 功能：展示提交信息、作者头像、提交时间、短哈希（可点击复制带视觉反馈）

### ChangedFileRow 变更文件行（CommitDetailView内定义）
- `file: ChangedFile` - 变更文件对象
- 功能：展示文件名、文件路径、状态图标、新增/删除行数

### FileDiffView 文件Diff视图（CommitDetailView内定义）
- `file: ChangedFile` - 变更文件对象，包含patch内容
- 内部状态：
  - `scale: CGFloat` - 当前缩放比例
  - `lastScale: CGFloat` - 上一次缩放比例
- 功能：展示文件Diff内容，支持行号显示、新增行绿色、删除行红色、变更标记蓝色、双指缩放

## 核心功能
1. **提交列表展示**：提交信息、作者头像、相对时间、短哈希（可点击复制带视觉反馈）
2. **下拉刷新**：下拉刷新提交列表
3. **无限滚动**：滚动到底部自动加载更多提交（使用last sha分页，自动去重）
4. **提交详情**：提交信息、作者头像、提交时间、完整哈希（可复制）、提交统计（新增/删除/文件数）
5. **变更文件列表**：文件名、文件路径、状态图标（新增/修改/删除/重命名）、新增/删除行数
6. **文件Diff对比**：行号显示、新增行绿色背景、删除行红色背景、变更标记蓝色、使用LazyVStack优化大文件性能
7. **大文件优化**：使用LazyVStack优化Diff渲染性能，支持流畅打开1MB以上文件
8. **双指缩放**：Diff视图支持双指缩放（0.5x-2.0x）
9. **操作提示**：复制哈希成功显示Toast提示
10. **深色模式适配**：所有视图适配深色模式
11. **空状态/错误状态**：完整的加载、空、错误状态展示

## 依赖模块
- `GitHub/Models/Commit.swift` - 提交数据模型
- `GitHub/Models/Workflow.swift` - ChangedFile数据模型（第551行）
- `GitHub/Core/Network/GitHubAPI.swift` - GitHub API网络请求
- `GitHub/Core/Utils/AppState.swift` - 应用全局状态（深色模式等）
