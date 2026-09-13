# Settings 仓库设置模块

## 模块说明
本模块负责仓库设置与统计信息的展示与管理，包含仓库基本信息、仓库设置（重命名、修改描述、切换公开/私有、删除仓库）、仓库统计信息等功能。仅对自己的仓库显示设置选项，别人的仓库只显示信息。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `RepositorySettingsView.swift` | 仓库设置视图，展示仓库基本信息，支持重命名、修改描述、切换公开/私有、删除仓库（仅自己的仓库） |
| `RepositoryStatsView.swift` | 仓库统计视图，展示仓库概览统计、详细统计、仓库信息 |

## 功能参数说明

### RepositorySettingsView 仓库设置
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- 内部状态：
  - `repository: Repository?` - 仓库信息对象
  - `isLoading: Bool` - 加载中状态
  - `errorMessage: String?` - 错误信息
  - `showEditName: Bool` - 是否显示编辑名称弹窗
  - `showEditDescription: Bool` - 是否显示编辑描述弹窗
  - `newName: String` - 新仓库名称
  - `newDescription: String` - 新仓库描述
  - `isSaving: Bool` - 保存中状态
  - `showToggleVisibilityConfirm: Bool` - 是否显示切换公开/私有确认弹窗
  - `isTogglingVisibility: Bool` - 切换公开/私有中状态
  - `showDeleteConfirm: Bool` - 是否显示删除仓库确认弹窗
  - `deleteConfirmationText: String` - 删除确认文本（需输入仓库名确认）
  - `isDeleting: Bool` - 删除中状态
- 计算属性：
  - `isOwnRepository: Bool` - 是否是自己的仓库（决定是否显示编辑选项）
- 核心函数：
  - `loadRepository()` - 加载仓库信息
  - `saveName()` - 保存仓库名称
  - `saveDescription()` - 保存仓库描述
  - `toggleVisibility()` - 切换公开/私有
  - `deleteRepository()` - 删除仓库
  - `loadingSection` - 加载中区域
  - `errorSection(error:)` - 错误区域
  - `basicInfoSection(repo:)` - 基本信息区域
  - `settingsSection(repo:)` - 设置选项区域（仅自己的仓库）
  - `dangerZoneSection(repo:)` - 危险操作区域（仅自己的仓库）
  - `otherRepoInfoSection(repo:)` - 别人仓库信息区域

### RepositoryStatsView 仓库统计
- `owner: String` - 仓库所有者
- `repo: String` - 仓库名称
- 内部状态：
  - `repository: Repository?` - 仓库信息对象
  - `isLoading: Bool` - 加载中状态
  - `errorMessage: String?` - 错误信息
- 核心函数：
  - `loadRepository()` - 加载仓库信息
  - `loadingSection` - 加载中区域
  - `errorSection(error:)` - 错误区域
  - `overviewSection(repo:)` - 概览统计区域
  - `detailsSection(repo:)` - 详细统计区域
  - `infoSection(repo:)` - 仓库信息区域

## 核心功能
1. **仓库基本信息**：展示仓库名称、描述、所有者、创建时间、更新时间等
2. **重命名仓库**：支持修改仓库名称（仅自己的仓库）
3. **修改描述**：支持修改仓库描述（仅自己的仓库）
4. **切换公开/私有**：支持切换仓库可见性（仅自己的仓库，带二次确认）
5. **删除仓库**：支持删除仓库（仅自己的仓库，需输入仓库名确认）
6. **仓库统计**：展示仓库Star数、Fork数、Watch数、Issues数、PR数等统计
7. **详细统计**：展示仓库大小、语言、开源协议、默认分支等详细信息
8. **权限控制**：自动判断是否是自己的仓库，仅显示有权限的操作
9. **别人仓库**：别人的仓库只显示信息，不显示设置选项
10. **深色模式适配**：所有视图适配深色模式
11. **加载/错误/空状态**：完整的状态展示
12. **下拉刷新**：支持下拉刷新仓库信息

## 依赖模块
- `GitHub/Models/Repository.swift` - 仓库数据模型
- `GitHub/Core/Network/GitHubAPI.swift` - GitHub API网络请求
- `GitHub/Core/Utils/AppState.swift` - 应用全局状态
- `GitHub/Core/Utils/AccountManager.swift` - 账号管理器
