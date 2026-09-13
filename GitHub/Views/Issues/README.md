# Issues 议题管理模块

## 模块说明
本模块负责仓库Issues（议题）的展示与管理，包含Issues列表、Issue详情、评论、新建Issue、关闭/重新打开Issue等功能。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `IssuesListView.swift` | Issues列表视图，展示仓库Issues列表，支持状态筛选（开放/已关闭/全部）、无限滚动、下拉刷新、新建Issue |
| `IssueDetailView.swift` | Issue详情视图，展示Issue详细信息、描述、评论列表，支持添加评论、关闭Issue、重新打开Issue |

## 功能参数说明

### IssuesListView Issues列表
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- 内部状态：
  - `issues: [Issue]` - Issues列表数组
  - `isLoading: Bool` - 加载中状态
  - `errorMessage: String?` - 错误信息
  - `selectedState: String` - 选中的状态筛选（open/closed/all）
  - `currentPage: Int` - 当前页码
  - `hasMore: Bool` - 是否有更多数据
  - `isLoadingMore: Bool` - 加载更多中状态
  - `showCreateIssue: Bool` - 是否显示新建Issue弹窗
  - `newIssueTitle: String` - 新Issue标题
  - `newIssueBody: String` - 新Issue正文
  - `isCreating: Bool` - 创建中状态
  - `selectedIssue: Issue?` - 选中的Issue（用于跳转详情）
- 核心函数：
  - `loadIssues()` - 加载Issues列表
  - `loadMoreIssues()` - 加载更多Issues
  - `createIssue()` - 创建新Issue
  - `loadingView` - 加载中视图
  - `errorView(error:)` - 错误视图
  - `emptyView` - 空状态视图
  - `issuesList` - Issues列表视图
  - `createIssueSheet` - 新建Issue弹窗

### IssueDetailView Issue详情
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- `issue: Issue` - Issue对象
- 内部状态：
  - `comments: [IssueComment]` - 评论列表数组
  - `isLoadingComments: Bool` - 评论加载中状态
  - `commentsError: String?` - 评论错误信息
  - `newComment: String` - 新评论内容
  - `isAddingComment: Bool` - 添加评论中状态
  - `isUpdatingState: Bool` - 更新状态中（关闭/重新打开）
- 核心函数：
  - `loadComments()` - 加载评论列表
  - `addComment()` - 添加评论
  - `closeIssue()` - 关闭Issue
  - `reopenIssue()` - 重新打开Issue
  - `issueHeader` - Issue头部信息视图
  - `issueBody(_:)` - Issue描述视图
  - `commentsSection` - 评论列表区域
  - `addCommentSection` - 添加评论区域

## 核心功能
1. **Issues列表**：展示仓库所有Issues，支持状态筛选（开放/已关闭/全部）
2. **无限滚动**：滚动到底部自动加载更多Issues
3. **下拉刷新**：下拉刷新Issues列表
4. **新建Issue**：支持创建新Issue（标题+正文）
5. **Issue详情**：展示Issue详细信息、描述、评论列表
6. **添加评论**：支持在Issue详情页添加评论
7. **关闭Issue**：支持关闭开放状态的Issue
8. **重新打开**：支持重新打开已关闭的Issue
9. **状态筛选**：支持按开放/已关闭/全部筛选Issues
10. **深色模式适配**：所有视图适配深色模式
11. **加载/错误/空状态**：完整的状态展示

## 依赖模块
- `GitHub/Models/Issue.swift` - Issue数据模型
- `GitHub/Models/IssueComment.swift` - Issue评论数据模型
- `GitHub/Core/Network/GitHubAPI.swift` - GitHub API网络请求
- `GitHub/Core/Utils/AppState.swift` - 应用全局状态
- `GitHub/Core/Utils/AccountManager.swift` - 账号管理器
