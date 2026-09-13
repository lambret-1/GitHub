# PullRequests 拉取请求管理模块

## 模块说明
本模块负责仓库Pull Requests（拉取请求/合并请求）的展示与管理，包含PR列表、PR详情、评论、审查、提交、文件变更、新建PR、合并/关闭PR等功能。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `PullRequestsListView.swift` | PR列表视图，展示仓库Pull Requests列表，支持状态筛选（开放/已关闭/全部）、无限滚动、下拉刷新、新建PR |
| `PullRequestDetailView.swift` | PR详情视图，展示PR详细信息、对话、提交、文件变更，支持添加评论、合并PR、关闭PR、重新打开PR |

## 功能参数说明

### PullRequestsListView PR列表
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- 内部状态：
  - `pullRequests: [PullRequest]` - PR列表数组
  - `isLoading: Bool` - 加载中状态
  - `errorMessage: String?` - 错误信息
  - `selectedState: String` - 选中的状态筛选（open/closed/all）
  - `currentPage: Int` - 当前页码
  - `hasMore: Bool` - 是否有更多数据
  - `isLoadingMore: Bool` - 加载更多中状态
  - `showCreatePR: Bool` - 是否显示新建PR弹窗
  - `newPRTitle: String` - 新PR标题
  - `newPRHead: String` - 新PR源分支
  - `newPRBase: String` - 新PR目标分支（默认main）
  - `newPRBody: String` - 新PR正文
  - `isCreating: Bool` - 创建中状态
  - `selectedPR: PullRequest?` - 选中的PR（用于跳转详情）
- 核心函数：
  - `loadPullRequests()` - 加载PR列表
  - `loadMorePullRequests()` - 加载更多PR
  - `createPullRequest()` - 创建新PR
  - `loadingView` - 加载中视图
  - `errorView(error:)` - 错误视图
  - `emptyView` - 空状态视图
  - `prList` - PR列表视图
  - `createPRSheet` - 新建PR弹窗

### PullRequestDetailView PR详情
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- `pullRequest: PullRequest` - PR对象
- 内部状态：
  - `selectedTab: PRTab` - 当前选中的Tab（conversation/commits/files）
  - `comments: [PullRequestComment]` - 评论列表数组
  - `isLoadingComments: Bool` - 评论加载中状态
  - `commentsError: String?` - 评论错误信息
  - `reviews: [PullRequestReview]` - 审查列表数组
  - `isLoadingReviews: Bool` - 审查加载中状态
  - `commits: [PullRequestCommit]` - 提交列表数组
  - `isLoadingCommits: Bool` - 提交加载中状态
  - `files: [PullRequestFile]` - 变更文件列表数组
  - `isLoadingFiles: Bool` - 文件加载中状态
  - `newComment: String` - 新评论内容
  - `isAddingComment: Bool` - 添加评论中状态
  - `isUpdatingState: Bool` - 更新状态中（合并/关闭/重新打开）
  - `showMergeConfirm: Bool` - 是否显示合并确认弹窗
- 枚举类型：
  - `PRTab` - Tab类型：conversation（对话）、commits（提交）、files（文件变更）
- 核心函数：
  - `loadComments()` - 加载评论列表
  - `loadReviews()` - 加载审查列表
  - `loadCommits()` - 加载提交列表
  - `loadFiles()` - 加载变更文件列表
  - `addComment()` - 添加评论
  - `mergePullRequest()` - 合并PR
  - `closePullRequest()` - 关闭PR
  - `reopenPullRequest()` - 重新打开PR
  - `prHeader` - PR头部信息视图
  - `branchInfo` - 分支信息和变更统计视图
  - `prTabBar` - Tab切换栏
  - `conversationContent` - 对话Tab内容
  - `commitsContent` - 提交Tab内容
  - `filesContent` - 文件变更Tab内容

## 核心功能
1. **PR列表**：展示仓库所有Pull Requests，支持状态筛选（开放/已关闭/全部）
2. **无限滚动**：滚动到底部自动加载更多PR
3. **下拉刷新**：下拉刷新PR列表
4. **新建PR**：支持创建新PR（标题+源分支+目标分支+正文）
5. **PR详情**：展示PR详细信息、分支信息、变更统计
6. **Tab切换**：支持对话/提交/文件变更三个Tab切换
7. **对话评论**：展示PR对话和评论，支持添加评论
8. **审查列表**：展示PR代码审查记录
9. **提交列表**：展示PR包含的所有提交
10. **文件变更**：展示PR变更的文件列表和Diff
11. **合并PR**：支持合并开放状态的PR（带二次确认）
12. **关闭PR**：支持关闭开放状态的PR
13. **重新打开**：支持重新打开已关闭的PR
14. **状态筛选**：支持按开放/已关闭/全部筛选PR
15. **深色模式适配**：所有视图适配深色模式
16. **加载/错误/空状态**：完整的状态展示

## 依赖模块
- `GitHub/Models/PullRequest.swift` - PR数据模型
- `GitHub/Models/PullRequestComment.swift` - PR评论数据模型
- `GitHub/Models/PullRequestReview.swift` - PR审查数据模型
- `GitHub/Models/PullRequestCommit.swift` - PR提交数据模型
- `GitHub/Models/PullRequestFile.swift` - PR变更文件数据模型
- `GitHub/Core/Network/GitHubAPI.swift` - GitHub API网络请求
- `GitHub/Core/Utils/AppState.swift` - 应用全局状态
- `GitHub/Core/Utils/AccountManager.swift` - 账号管理器
