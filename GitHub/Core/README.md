# 核心功能目录

本目录存放应用的核心功能模块，包括钥匙串管理、网络请求层和工具类。

## 子目录说明

### Keychain/
**钥匙串管理目录** - 安全存储用户 Token 等敏感信息

**文件清单：**
- `TokenKeychain.swift` - Token钥匙串管理，支持保存、读取、删除Token，支持多账号管理

### Network/
**网络请求层目录** - GitHub API 封装、端点定义、镜像会话管理

**文件清单：**
- `GitHubAPI.swift` - GitHub API核心封装，包含所有API请求方法
- `APIEndpoints.swift` - API端点定义，统一管理所有API URL

### Utils/
**工具类目录** - 应用状态、账号管理、设置、版本、下载、缓存等工具类

**文件清单：**
- `AppState.swift` - 应用全局状态管理（暗黑模式、当前用户、登录状态等）
- `AccountManager.swift` - 多账号管理和切换
- `AppVersion.swift` - 应用版本检查和更新管理
- `FileDownloadManager.swift` - 文件下载管理
- `ImageCache.swift` - 图片缓存管理（支持一天自动清理）
- `DateUtils.swift` - 日期工具类（相对时间格式化等）
- `TextFieldStyle.swift` - 文本框样式
- `LastCommitCache.swift` - 最后提交信息缓存

---

## 核心架构说明

### 分层架构

```
Views (视图层)
    ↓ 调用
Core/Utils (工具层) - 状态管理、缓存、下载
    ↓ 调用
Core/Network (网络层) - API 封装、请求管理
    ↓ 调用
GitHub API (远程服务)
```

### 数据流向

1. 视图层发起用户操作
2. 工具层处理业务逻辑和状态管理
3. 网络层发起 API 请求
4. 网络层返回数据模型
5. 工具层缓存数据并通知视图更新
6. 视图层渲染界面

---

## 核心功能参数说明

### TokenKeychain Token钥匙串

| 方法 | 中文释义 | 参数 | 返回值 |
|------|---------|------|--------|
| `saveToken(_:)` | 保存Token | `token: String` - Token字符串 | `Bool` - 是否保存成功 |
| `getToken()` | 获取Token | 无 | `String?` - Token字符串（可选） |
| `deleteToken()` | 删除Token | 无 | `Bool` - 是否删除成功 |
| `getUsername()` | 获取用户名 | 无 | `String?` - 用户名（可选） |

### AppState 应用状态

| 属性/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `isLoggedIn` | 是否已登录 | 用户登录状态 |
| `currentUser` | 当前用户 | 当前登录的GitHub用户对象 |
| `isLoading` | 加载中 | 全局加载状态 |
| `errorMessage` | 错误信息 | 全局错误信息 |
| `isDarkMode` | 暗黑模式 | 是否启用暗黑模式 |
| `showUpdateAlert` | 显示更新提醒 | 是否显示更新提醒弹窗 |
| `latestRelease` | 最新版本 | 最新版本信息 |
| `isDownloadingUpdate` | 下载更新中 | 是否正在下载更新 |
| `updateDownloadProgress` | 更新下载进度 | 更新下载进度（0-1） |

### GitHubAPI GitHub API

| 方法分类 | 中文释义 | 说明 |
|---------|---------|------|
| `getUser()` | 获取用户信息 | 获取当前登录用户信息 |
| `getRepositories()` | 获取仓库列表 | 获取用户仓库列表 |
| `getStarredRepositories()` | 获取星标仓库列表 | 获取用户星标的仓库列表 |
| `checkStarred()` | 检查星标状态 | 检查仓库是否已被星标 |
| `starRepository()` | 星标仓库 | 星标指定仓库 |
| `unstarRepository()` | 取消星标 | 取消星标指定仓库 |
| `forkRepository()` | Fork仓库 | Fork指定仓库 |
| `getRepository()` | 获取仓库信息 | 获取指定仓库详细信息 |
| `getContents()` | 获取文件内容 | 获取仓库文件/目录内容 |
| `createFile()` | 创建文件 | 创建新文件 |
| `updateFile()` | 更新文件 | 更新已有文件 |
| `deleteFile()` | 删除文件 | 删除指定文件 |
| `getBranches()` | 获取分支列表 | 获取仓库分支列表 |
| `createBranch()` | 创建分支 | 创建新分支 |
| `renameBranch()` | 重命名分支 | 重命名指定分支 |
| `deleteBranch()` | 删除分支 | 删除指定分支 |
| `getCommits()` | 获取提交列表 | 获取仓库提交历史 |
| `getCommitFiles()` | 获取提交变更文件 | 获取指定提交的变更文件列表 |
| `getIssues()` | 获取Issues列表 | 获取仓库Issues列表 |
| `getPullRequests()` | 获取PR列表 | 获取仓库Pull Requests列表 |
| `getWorkflows()` | 获取工作流列表 | 获取仓库Actions工作流列表 |
| `getWorkflowRuns()` | 获取运行记录 | 获取工作流运行记录列表 |
| `getJobLogs()` | 获取作业日志 | 获取指定作业的日志 |
| `searchRepositories()` | 搜索仓库 | 搜索GitHub仓库 |
| `searchUsers()` | 搜索用户 | 搜索GitHub用户 |
| `searchCode()` | 搜索代码 | 搜索仓库代码 |

---

## 安全规范

1. Token 等敏感信息必须存储在 Keychain 中，禁止使用 UserDefaults
2. API 请求必须使用 HTTPS
3. 镜像加速仅用于公开资源，API 请求始终使用官方 GitHub 服务器
4. 禁止在日志中输出 Token 等敏感信息
5. 网络请求错误处理必须完善，避免崩溃
6. 所有网络请求必须在后台线程执行，完成后在主线程更新UI
7. API请求必须使用正确的请求头（Authorization: token xxx）
8. 私有仓库下载必须使用API请求头，确保完整可访问的API
