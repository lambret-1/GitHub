# RepoList 仓库列表模块

## 模块说明
本模块负责仓库列表的展示与管理，包含我的仓库列表、星标仓库列表、仓库卡片展示等功能。星标仓库列表全新重构，对齐GitHub官方样式，支持搜索、筛选、排序、左滑取消星标、重按菜单等高级功能。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `RepoListView.swift` | 我的仓库列表视图，展示当前用户的仓库列表，支持下拉刷新、无限滚动、搜索筛选、仓库行组件、筛选标签组件 |
| `StarredReposView.swift` | 星标仓库列表视图，展示用户收藏的仓库，全新重构对齐GitHub官方样式，支持搜索、筛选、排序、左滑取消星标、重按菜单、无限滚动、下拉刷新 |

## 功能参数说明

### RepoListView 仓库列表
- 无外部参数，使用当前登录用户的Token加载仓库列表
- 内部状态：
  - `repos: [Repository]` - 仓库列表数组
  - `isLoading: Bool` - 加载中状态
  - `errorMessage: String?` - 错误信息
  - `currentPage: Int` - 当前页码
  - `hasMorePages: Bool` - 是否有更多数据
  - `isLoadingMore: Bool` - 加载更多中状态
  - `searchText: String` - 搜索文本
  - `selectedFilter: String` - 选中的筛选类型

### StarredReposView 星标仓库列表（全新重构）
- 无外部参数，使用当前登录用户的Token加载星标仓库列表
- 内部状态：
  - `repos: [Repository]` - 星标仓库列表数组
  - `isLoading: Bool` - 加载中状态
  - `errorMessage: String?` - 错误信息
  - `currentPage: Int` - 当前页码
  - `hasMorePages: Bool` - 是否有更多数据
  - `isLoadingMore: Bool` - 加载更多中状态
  - `searchText: String` - 搜索文本
  - `isSearching: Bool` - 搜索中状态
  - `selectedFilter: FilterType` - 选中的筛选类型（all/own/others）
  - `selectedSort: SortType` - 选中的排序类型（starredTime/repoName/updateTime/stars）
  - `showSortMenu: Bool` - 是否显示排序菜单
  - `operationMessage: String` - 操作提示信息
  - `showOperationMessage: Bool` - 是否显示操作提示
- 计算属性：
  - `currentUsername: String` - 当前登录用户名（从appState.currentUser获取）
  - `filteredRepos: [Repository]` - 过滤后的仓库列表（按筛选类型、搜索文本、排序类型过滤）
- 枚举类型：
  - `FilterType` - 筛选类型：all（全部）、own（自己的）、others（别人的）
  - `SortType` - 排序类型：starredTime（星标时间）、repoName（仓库名）、updateTime（更新时间）、stars（Star数）

### RepoRow 仓库行（RepoListView内定义）
- `repo: Repository` - 仓库对象
- 功能：展示仓库图标、仓库名、语言标签、描述、Star数、Fork数、更新时间

### StarredRepoCard 星标仓库卡片（StarredReposView内定义）
- `repo: Repository` - 仓库对象
- 功能：圆角卡片样式，展示仓库图标、所有者/仓库名、星标图标、描述、语言标签、Star数、Fork数、更新时间，适配深色模式

### FilterChip 筛选标签（RepoListView内定义）
- `title: String` - 标签标题
- `isSelected: Bool` - 是否选中
- `action: () -> Void` - 点击回调
- 功能：展示筛选标签，支持选中/未选中状态切换

## 核心功能
1. **我的仓库列表**：展示当前用户的所有仓库，支持下拉刷新、无限滚动加载更多
2. **星标仓库列表**：展示用户收藏的仓库，全新重构对齐GitHub官方样式
3. **搜索功能**：星标列表支持按仓库名/描述/所有者搜索，实时过滤
4. **筛选功能**：星标列表支持全部/自己的/别人的仓库筛选标签
5. **排序功能**：星标列表导航栏排序菜单，支持按星标时间/仓库名/更新时间/Star数排序
6. **左滑取消星标**：星标列表支持左滑手势快速取消星标
7. **重按菜单**：星标列表支持重按弹出菜单（取消星标/在GitHub打开/复制仓库地址）
8. **无限滚动**：滚动到底部自动加载更多仓库（自动去重）
9. **下拉刷新**：下拉刷新仓库列表
10. **仓库卡片**：圆角卡片样式，展示仓库图标、所有者/仓库名、星标图标、描述、语言标签（带颜色圆点）、Star数、Fork数、更新时间
11. **深色模式适配**：所有视图适配深色模式
12. **操作提示**：取消星标成功/失败显示Toast提示
13. **空状态/错误状态**：完整的加载、空、错误状态展示
14. **仓库数量显示**：筛选标签栏右侧显示当前过滤后的仓库数量

## 依赖模块
- `GitHub/Models/Repository.swift` - 仓库数据模型
- `GitHub/Core/Network/GitHubAPI.swift` - GitHub API网络请求
- `GitHub/Core/Utils/AppState.swift` - 应用全局状态（当前用户、深色模式等）
- `GitHub/Core/Keychain/TokenKeychain.swift` - Token钥匙串管理
- `GitHub/Views/FileBrowser/FileBrowserView.swift` - 点击仓库跳转到文件浏览器
