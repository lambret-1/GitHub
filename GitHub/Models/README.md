# 数据模型目录

本目录存放应用的所有数据模型，包括 GitHub API 响应的数据结构定义。

## 文件说明

### Repository.swift
**仓库数据模型**

**功能参数说明：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `id` | 仓库 ID | GitHub 仓库的唯一数字标识 |
| `name` | 仓库名称 | 仓库的短名称 |
| `fullName` | 完整名称 | 所有者/仓库名称格式 |
| `description` | 仓库描述 | 仓库的描述文本（可选） |
| `language` | 主要语言 | 仓库的主要编程语言（可选） |
| `stargazersCount` | Star 数 | 仓库的 Star 数量 |
| `forksCount` | Fork 数 | 仓库的 Fork 数量 |
| `watchersCount` | 关注者数 | 仓库的关注者数量 |
| `openIssuesCount` | 开放议题数 | 仓库的开放议题数量 |
| `isPrivate` | 是否私有 | 仓库是否为私有仓库 |
| `htmlUrl` | 网页 URL | 仓库的 GitHub 网页地址 |
| `defaultBranch` | 默认分支 | 仓库的默认分支名 |
| `updatedAt` | 更新时间 | 仓库最后更新时间（ISO 8601 格式） |
| `createdAt` | 创建时间 | 仓库创建时间（ISO 8601 格式） |
| `owner` | 所有者 | 仓库所有者信息（RepositoryOwner 模型） |
| `ownerName` | 所有者名称 | 计算属性，返回所有者登录名 |
| `formattedUpdateTime` | 格式化更新时间 | 计算属性，返回北京时间格式的更新时间 |
| `languageColor` | 语言颜色 | 计算属性，返回编程语言对应的十六进制颜色值 |

**RepositoryOwner 子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `login` | 登录名 | 所有者的 GitHub 登录名 |
| `id` | 用户 ID | 所有者的唯一数字标识 |
| `avatarUrl` | 头像 URL | 所有者的头像图片地址 |

---

### FileItem.swift
**文件项数据模型**

**功能参数说明：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `name` | 文件名称 | 文件或文件夹的名称 |
| `path` | 文件路径 | 文件在仓库中的完整路径 |
| `sha` | 文件哈希 | 文件的 Git SHA 哈希值 |
| `size` | 文件大小 | 文件大小（字节），文件夹为 0 |
| `type` | 文件类型 | "file"（文件）或 "dir"（文件夹） |
| `downloadUrl` | 下载 URL | 文件的下载地址（可选） |
| `htmlUrl` | 网页 URL | 文件的 GitHub 网页地址（可选） |
| `isDirectory` | 是否为目录 | 计算属性，判断是否为文件夹 |
| `fileExtension` | 文件扩展名 | 计算属性，返回文件扩展名 |
| `formattedSize` | 格式化大小 | 计算属性，返回人类可读的文件大小 |

**文件类型说明：**
- `file`：普通文件
- `dir`：目录/文件夹
- `submodule`：Git 子模块
- `symlink`：符号链接

---

### User.swift
**用户数据模型**

**功能参数说明：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `login` | 登录名 | 用户的 GitHub 登录名 |
| `id` | 用户 ID | 用户的唯一数字标识 |
| `avatarUrl` | 头像 URL | 用户的头像图片地址 |
| `htmlUrl` | 网页 URL | 用户的 GitHub 主页地址 |
| `name` | 显示名称 | 用户的显示名称（可选） |
| `bio` | 个人简介 | 用户的个人简介文本（可选） |
| `location` | 位置 | 用户的地理位置（可选） |
| `company` | 公司 | 用户所属公司（可选） |
| `blog` | 博客 | 用户的博客地址（可选） |
| `email` | 邮箱 | 用户的公开邮箱（可选） |
| `publicRepos` | 公开仓库数 | 用户的公开仓库数量 |
| `followers` | 关注者数 | 用户的关注者数量 |
| `following` | 关注数 | 用户关注的人数 |
| `createdAt` | 创建时间 | 账号创建时间（ISO 8601 格式） |
| `updatedAt` | 更新时间 | 账号最后更新时间（ISO 8601 格式） |

---

### Commit.swift
**提交记录数据模型**

**功能参数说明：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `sha` | 提交哈希 | 提交的 Git SHA 哈希值 |
| `commit` | 提交详情 | 提交的详细信息（CommitDetail 模型） |
| `author` | 作者 | 提交作者的 GitHub 用户信息（可选，CommitAuthor 模型） |
| `htmlUrl` | 网页 URL | 提交的 GitHub 网页地址 |
| `shortSha` | 短哈希 | 计算属性，返回前 7 位哈希 |
| `message` | 提交信息 | 计算属性，返回提交信息文本 |
| `authorName` | 作者名称 | 计算属性，返回作者名称 |
| `authorDate` | 作者日期 | 计算属性，返回作者提交日期 |
| `formattedDate` | 格式化日期 | 计算属性，返回北京时间格式的日期 |

**CommitDetail 子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `message` | 提交信息 | 提交的信息文本 |
| `author` | 作者 | 提交作者信息（CommitPerson 模型） |
| `committer` | 提交者 | 实际提交者信息（CommitPerson 模型） |

**CommitPerson 子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `name` | 名称 | 作者/提交者的名称 |
| `email` | 邮箱 | 作者/提交者的邮箱 |
| `date` | 日期 | 提交日期（ISO 8601 格式） |

**CommitAuthor 子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `login` | 登录名 | GitHub 用户登录名（可选） |
| `avatarUrl` | 头像 URL | 用户头像地址（可选） |

---

### GitHubAccount.swift
**GitHub 账号数据模型**

**功能参数说明：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `token` | 访问令牌 | GitHub Personal Access Token |
| `username` | 用户名 | GitHub 登录名 |
| `avatarUrl` | 头像 URL | 用户头像图片地址 |
| `addedAt` | 添加时间 | 账号添加时间戳 |
| `isCurrent` | 是否当前账号 | 标记是否为当前选中的账号 |

**用途：**
- 多账号管理
- 账号切换
- 账号添加和删除
- 本地持久化存储

---

### Workflow.swift
**GitHub Actions 数据模型**

**功能参数说明：**

**Workflow（工作流）子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `id` | 工作流 ID | 工作流的唯一数字标识 |
| `name` | 工作流名称 | 工作流的显示名称 |
| `path` | 文件路径 | 工作流 YAML 文件的路径 |
| `state` | 状态 | 工作流状态（active/disabled_manually/disabled_inactivity） |
| `createdAt` | 创建时间 | 工作流创建时间 |
| `updatedAt` | 更新时间 | 工作流最后更新时间 |
| `htmlUrl` | 网页 URL | 工作流的 GitHub 网页地址 |
| `badgeUrl` | 徽章 URL | 工作流状态徽章图片地址 |
| `stateDisplay` | 状态显示文本 | 计算属性，返回中文状态文本 |
| `fileName` | 文件名 | 计算属性，返回工作流文件名 |

**WorkflowRun（工作流运行）子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `id` | 运行 ID | 运行的唯一数字标识 |
| `name` | 运行名称 | 运行的显示名称 |
| `nodeId` | 节点 ID | 运行的节点标识 |
| `headBranch` | 头部分支 | 触发运行的分支名 |
| `headSha` | 头部哈希 | 触发运行的提交哈希 |
| `runNumber` | 运行编号 | 工作流的运行序号 |
| `event` | 触发事件 | 触发运行的事件类型 |
| `status` | 状态 | 运行状态（queued/in_progress/completed 等） |
| `conclusion` | 结论 | 运行结论（success/failure/cancelled 等，可选） |
| `workflowId` | 工作流 ID | 所属工作流的 ID |
| `url` | API URL | 运行的 API 地址 |
| `htmlUrl` | 网页 URL | 运行的 GitHub 网页地址 |
| `createdAt` | 创建时间 | 运行创建时间 |
| `updatedAt` | 更新时间 | 运行最后更新时间 |
| `runStartedAt` | 开始时间 | 实际开始执行时间（可选） |
| `jobsUrl` | 作业 URL | 作业列表的 API 地址 |
| `logsUrl` | 日志 URL | 日志的 API 地址 |
| `headCommit` | 头部提交 | 触发运行的提交信息（可选，HeadCommit 模型） |
| `actor` | 执行者 | 触发运行的用户信息（可选，Actor 模型） |
| `statusDisplay` | 状态显示文本 | 计算属性，返回中文状态文本 |
| `statusIcon` | 状态图标 | 计算属性，返回 SF Symbols 图标名 |
| `statusColor` | 状态颜色 | 计算属性，返回状态对应的颜色名 |
| `eventDisplay` | 事件显示文本 | 计算属性，返回中文事件文本 |
| `shortSha` | 短哈希 | 计算属性，返回前 7 位提交哈希 |
| `formattedCreatedAt` | 格式化创建时间 | 计算属性，返回北京时间格式 |

**WorkflowJob（工作流作业）子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `id` | 作业 ID | 作业的唯一数字标识 |
| `runId` | 运行 ID | 所属运行的 ID |
| `name` | 作业名称 | 作业的显示名称 |
| `status` | 状态 | 作业状态 |
| `conclusion` | 结论 | 作业结论（可选） |
| `startedAt` | 开始时间 | 作业开始时间（可选） |
| `completedAt` | 完成时间 | 作业完成时间（可选） |
| `steps` | 步骤列表 | 作业的步骤列表（可选，JobStep 模型数组） |
| `runnerName` | Runner 名称 | 执行作业的 Runner 名称（可选） |
| `statusDisplay` | 状态显示文本 | 计算属性，返回中文状态文本 |
| `statusIcon` | 状态图标 | 计算属性，返回 SF Symbols 图标名 |
| `statusColor` | 状态颜色 | 计算属性，返回状态对应的颜色名 |
| `durationSeconds` | 运行时长（秒） | 计算属性，返回作业运行时长（可选） |
| `durationDisplay` | 运行时长显示 | 计算属性，返回人类可读的运行时长 |

**JobStep（作业步骤）子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `name` | 步骤名称 | 步骤的显示名称 |
| `status` | 状态 | 步骤状态 |
| `conclusion` | 结论 | 步骤结论（可选） |
| `number` | 步骤序号 | 步骤在作业中的序号 |
| `startedAt` | 开始时间 | 步骤开始时间（可选） |
| `completedAt` | 完成时间 | 步骤完成时间（可选） |
| `statusDisplay` | 状态显示文本 | 计算属性，返回中文状态文本 |
| `statusIcon` | 状态图标 | 计算属性，返回 SF Symbols 图标名 |
| `statusColor` | 状态颜色 | 计算属性，返回状态对应的颜色名 |
| `durationSeconds` | 运行时长（秒） | 计算属性，返回步骤运行时长（可选） |
| `durationDisplay` | 运行时长显示 | 计算属性，返回人类可读的运行时长 |

**HeadCommit（头部提交）子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `id` | 提交哈希 | 提交的 SHA 哈希值 |
| `treeId` | 树哈希 | 提交的 Git 树哈希 |
| `message` | 提交信息 | 提交的信息文本 |
| `timestamp` | 时间戳 | 提交时间 |
| `author` | 作者 | 提交作者信息（可选，WorkflowCommitAuthor 模型） |
| `committer` | 提交者 | 实际提交者信息（可选，WorkflowCommitAuthor 模型） |

**WorkflowCommitAuthor（工作流提交作者）子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `name` | 名称 | 作者名称 |
| `email` | 邮箱 | 作者邮箱 |
| `username` | 用户名 | GitHub 用户名（可选） |

**Actor（执行者）子模型：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `login` | 登录名 | 用户的 GitHub 登录名 |
| `id` | 用户 ID | 用户的唯一数字标识 |
| `avatarUrl` | 头像 URL | 用户头像图片地址 |
| `htmlUrl` | 网页 URL | 用户的 GitHub 主页地址 |
| `type` | 用户类型 | 用户类型（User/Organization） |

---

## 数据模型规范

1. 所有模型必须遵循 Codable 协议
2. 所有模型必须遵循 Identifiable 协议（如有 id 字段）
3. API 字段名使用 snake_case，Swift 属性名使用 camelCase
4. 使用 CodingKeys 枚举映射字段名
5. 可选字段必须使用可选类型（?）
6. 计算属性用于格式化显示，不参与编码解码
7. 日期时间使用 ISO 8601 格式存储，显示时转换为北京时间
8. 新增模型时必须更新本 README 说明
