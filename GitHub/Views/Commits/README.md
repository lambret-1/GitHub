# Commits 提交记录模块

## 模块说明
本模块负责GitHub仓库提交记录的展示与详情查看，包含提交列表、提交详情、文件Diff对比等功能。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `CommitsListView.swift` | 提交记录列表视图，展示仓库的提交历史，支持下拉刷新、无限滚动加载更多、点击跳转详情 |
| `CommitDetailView.swift` | 提交详情视图，展示提交信息、作者、变更统计、变更文件列表，支持查看文件Diff |

## 功能参数说明

### CommitsListView 提交列表
- `owner: String` - 仓库所有者用户名
- `repo: String` - 仓库名称
- `branch: String?` - 分支名称（可选，为空时使用默认分支）

### CommitDetailView 提交详情
- `owner: String` - 仓库所有者用户名
- `repo: String` - 仓库名称
- `commit: Commit` - 提交对象，包含提交信息、作者、哈希等

### StarredRepoCard 星标仓库卡片（CommitsListView内定义）
- `repo: Repository` - 仓库对象

### ChangedFileRow 变更文件行（CommitDetailView内定义）
- `file: ChangedFile` - 变更文件对象

### FileDiffView 文件Diff视图（CommitDetailView内定义）
- `file: ChangedFile` - 变更文件对象，包含patch内容

## 核心功能
1. **提交列表展示**：提交信息、作者头像、提交时间、短哈希
2. **下拉刷新**：下拉刷新提交列表
3. **无限滚动**：滚动到底部自动加载更多提交
4. **提交详情**：提交信息、作者、完整哈希、变更统计
5. **变更文件列表**：文件名、路径、状态图标、新增/删除行数
6. **文件Diff对比**：行号显示、新增行绿色、删除行红色、变更标记蓝色
7. **大文件优化**：使用LazyVStack优化Diff渲染性能
8. **双指缩放**：Diff视图支持双指缩放
9. **深色模式适配**：所有视图适配深色模式
