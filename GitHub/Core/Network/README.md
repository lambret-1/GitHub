# 网络请求层目录

本目录存放网络请求相关的类，包括 GitHub API 封装、API 端点定义、镜像专用 URLSession 管理。

## 文件说明

### GitHubAPI.swift
**GitHub API 封装类** - 单例模式，封装所有 GitHub API 请求

**功能参数说明：**

| 方法名 | 中文释义 | 说明 |
|--------|---------|------|
| `shared` | 单例实例 | GitHubAPI 共享单例 |
| `getUserInfo()` | 获取用户信息 | 获取当前登录用户的详细信息 |
| `getUserRepos(page:perPage:)` | 获取用户仓库列表 | 获取当前用户的仓库列表，支持分页 |
| `searchRepos(query:page:sort:)` | 搜索仓库 | 根据查询字符串搜索 GitHub 仓库 |
| `searchUsers(query:page:sort:)` | 搜索用户 | 根据查询字符串搜索 GitHub 用户 |
| `getFileContent(owner:repo:path:branch:)` | 获取文件内容 | 获取指定仓库指定路径的文件内容 |
| `getDirectoryContents(owner:repo:path:branch:)` | 获取目录内容 | 获取指定仓库指定路径的目录内容列表 |
| `updateFile(owner:repo:path:content:sha:message:branch:)` | 更新文件 | 更新指定仓库的文件内容 |
| `createFile(owner:repo:path:content:message:branch:)` | 创建文件 | 在指定仓库创建新文件 |
| `uploadFileData(owner:repo:path:fileData:message:branch:)` | 上传文件数据 | 上传二进制文件数据到指定仓库 |
| `downloadFileData(url:)` | 下载文件数据 | 从指定 URL 下载文件数据（支持镜像加速） |
| `createDirectory(owner:repo:path:branch:)` | 创建目录 | 在指定仓库创建新目录（通过创建 .gitkeep） |
| `deleteFile(owner:repo:path:sha:message:branch:)` | 删除文件 | 删除指定仓库的文件 |
| `renameFile(owner:repo:oldPath:newPath:branch:)` | 重命名文件 | 重命名或移动指定仓库的文件 |
| `getFileLastCommit(owner:repo:path:branch:)` | 获取文件最后提交 | 获取指定文件的最后一次提交信息 |
| `getBranches(owner:repo:)` | 获取分支列表 | 获取指定仓库的所有分支 |
| `getCommits(owner:repo:path:)` | 获取提交记录 | 获取指定仓库的提交记录，可按路径筛选 |
| `getWorkflows(owner:repo:)` | 获取工作流列表 | 获取指定仓库的 GitHub Actions 工作流列表 |
| `getWorkflowRuns(owner:repo:page:perPage:)` | 获取运行记录 | 获取指定仓库的所有工作流运行记录 |
| `getWorkflowRunsForWorkflow(owner:repo:workflowId:page:perPage:)` | 获取指定工作流运行 | 获取指定工作流的运行记录 |
| `getWorkflowRun(owner:repo:runId:)` | 获取运行详情 | 获取单个工作流运行的详细信息 |
| `getWorkflowJobs(owner:repo:runId:)` | 获取作业列表 | 获取指定运行的作业列表 |
| `getJobLogs(owner:repo:jobId:)` | 获取作业日志 | 获取指定作业的完整日志文本 |
| `triggerWorkflowDispatch(owner:repo:workflowId:ref:inputs:)` | 触发工作流 | 手动触发指定工作流运行（workflow_dispatch） |
| `cancelWorkflowRun(owner:repo:runId:)` | 取消运行 | 取消正在进行的工作流运行 |
| `rerunWorkflowRun(owner:repo:runId:)` | 重新运行 | 重新运行已完成的工作流 |
| `performRequest(url:method:body:)` | 执行请求 | 底层 HTTP 请求执行方法 |
| `getHeaders()` | 获取请求头 | 获取包含 Authorization 的请求头 |

**参数说明：**

| 参数名 | 中文释义 | 说明 |
|--------|---------|------|
| `owner` | 仓库所有者 | GitHub 用户名或组织名 |
| `repo` | 仓库名称 | GitHub 仓库名称 |
| `path` | 文件路径 | 仓库内的文件或目录路径 |
| `branch` | 分支名 | 操作的目标分支，默认 main |
| `page` | 页码 | 分页查询的页码，从 1 开始 |
| `perPage` | 每页数量 | 每页返回的结果数量 |
| `query` | 查询字符串 | 搜索查询字符串 |
| `sort` | 排序方式 | 结果排序方式 |
| `sha` | 文件哈希 | 文件的 Git SHA 哈希值 |
| `message` | 提交信息 | Git 提交信息 |
| `content` | 文件内容 | 文件的文本内容 |
| `fileData` | 文件数据 | 文件的二进制数据 |
| `workflowId` | 工作流 ID | GitHub Actions 工作流的唯一标识 |
| `runId` | 运行 ID | 工作流运行的唯一标识 |
| `jobId` | 作业 ID | 工作流作业的唯一标识 |
| `ref` | 引用 | 触发工作流的 Git 引用（分支/标签） |
| `inputs` | 输入参数 | 工作流的输入参数字典 |
| `token` | 访问令牌 | GitHub Personal Access Token |

---

### APIEndpoints.swift
**API 端点定义文件** - 枚举类型，定义所有 GitHub API 请求的 URL

**功能参数说明：**

| 枚举值 | 中文释义 | 说明 |
|--------|---------|------|
| `user` | 用户信息端点 | `/user` - 获取当前用户信息 |
| `userRepos(page:perPage:)` | 用户仓库端点 | `/user/repos` - 获取用户仓库列表 |
| `repoContent(owner:repo:path:branch:)` | 仓库内容端点 | `/repos/{owner}/{repo}/contents/{path}` - 获取文件/目录内容 |
| `updateFile(owner:repo:path:)` | 更新文件端点 | `/repos/{owner}/{repo}/contents/{path}` - 创建/更新/删除文件 |
| `repoBranches(owner:repo:)` | 仓库分支端点 | `/repos/{owner}/{repo}/branches` - 获取分支列表 |
| `commits(owner:repo:path:)` | 提交记录端点 | `/repos/{owner}/{repo}/commits` - 获取提交记录 |
| `searchRepos(query:page:)` | 搜索仓库端点 | `/search/repositories` - 搜索仓库 |
| `searchUsers(query:page:)` | 搜索用户端点 | `/search/users` - 搜索用户 |
| `workflows(owner:repo:)` | 工作流端点 | `/repos/{owner}/{repo}/actions/workflows` - 获取工作流列表 |
| `workflowRuns(owner:repo:page:perPage:)` | 运行记录端点 | `/repos/{owner}/{repo}/actions/runs` - 获取运行记录 |
| `workflowRunsForWorkflow(owner:repo:workflowId:page:perPage:)` | 指定工作流运行端点 | `/repos/{owner}/{repo}/actions/workflows/{id}/runs` |
| `workflowRun(owner:repo:runId:)` | 运行详情端点 | `/repos/{owner}/{repo}/actions/runs/{id}` - 获取运行详情 |
| `workflowJobs(owner:repo:runId:)` | 作业列表端点 | `/repos/{owner}/{repo}/actions/runs/{id}/jobs` - 获取作业列表 |
| `jobLogs(owner:repo:jobId:)` | 作业日志端点 | `/repos/{owner}/{repo}/actions/jobs/{id}/logs` - 获取作业日志 |
| `workflowDispatch(owner:repo:workflowId:)` | 触发工作流端点 | `/repos/{owner}/{repo}/actions/workflows/{id}/dispatches` |
| `cancelWorkflowRun(owner:repo:runId:)` | 取消运行端点 | `/repos/{owner}/{repo}/actions/runs/{id}/cancel` |
| `rerunWorkflowRun(owner:repo:runId:)` | 重新运行端点 | `/repos/{owner}/{repo}/actions/runs/{id}/rerun` |
| `baseURL` | 基础 URL | `https://api.github.com` - GitHub API 基础地址 |
| `url` | 完整 URL | 计算属性，根据枚举值生成完整的 API 请求 URL |

**重要说明：**
- API 请求始终使用官方 API 地址（`https://api.github.com`）
- 不使用镜像加速，避免镜像服务器缓存其他用户的认证响应
- 镜像加速仅用于文件下载、网页预览、头像加载等公开资源

---

### MirrorURLSession.swift
**镜像专用 URLSession 管理文件**

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `mirrorSession` | 镜像专用会话 | 用于镜像加速下载的 URLSession 单例 |
| `MirrorSessionDelegate` | 镜像会话代理 | 自定义 URLSessionDelegate，允许无效证书 |
| `urlSession(_:didReceive:completionHandler:)` | 证书验证回调 | 处理 HTTPS 证书验证，允许镜像站点的无效证书 |
| `useMirror` | 是否使用镜像 | 下载任务的参数，控制是否走镜像加速 |

**使用场景：**
- 文件下载（支持镜像加速）
- HTML 网页预览（支持镜像加速）
- 头像加载（不使用镜像，直接从官方加载）
- 更新下载（不使用镜像，直接从官方下载，避免重定向问题）

**安全策略：**
- API 请求（需要认证的）始终使用官方 GitHub 服务器
- 镜像加速仅用于公开资源下载
- 镜像站点可能使用自签名证书，因此允许无效证书
- 自定义镜像地址由用户配置，需用户自行确认安全性

---

## 网络层规范

1. 所有 API 请求必须通过 GitHubAPI 单例发起
2. API 端点必须在 APIEndpoints 枚举中定义
3. 请求完成后必须在主线程回调
4. 错误处理必须完善，避免崩溃
5. 网络请求必须设置超时时间
6. 大文件下载必须支持进度回调
7. 镜像加速仅用于公开资源，API 请求始终使用官方地址
