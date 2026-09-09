# GitHub iOS 客户端

一个轻量级的 GitHub iOS 客户端，支持 Token 安全登录，可随时随地查看和编辑代码。

## 功能特性

### 🔐 安全登录
- Personal Access Token 一键登录
- Token 存储在系统 Keychain 中，安全可靠
- 支持自动登录，无需重复输入

### 📁 仓库管理
- 查看所有公开和私有仓库
- 支持仓库搜索和筛选（全部/我的/私有/公开）
- 显示仓库语言、Star、Fork、更新时间等信息
- 下拉刷新最新仓库列表

### 📂 文件浏览
- 树形目录结构浏览仓库文件
- 支持多级目录导航
- 显示文件大小、类型图标
- 支持切换不同分支

### ✏️ 代码编辑
- 在线查看代码文件，支持行号显示
- 代码字体大小可调节
- 支持编辑修改文件内容
- 自定义提交信息，一键提交到 GitHub
- 支持复制代码内容

### 👤 个人中心
- 展示 GitHub 头像、昵称、简介
- 显示仓库数、粉丝数、关注数
- 查看公司、位置、博客等个人信息
- 一键退出登录

### 📝 提交记录
- 查看仓库提交历史
- 显示提交信息、作者、时间
- 短 SHA 标识

## 技术栈

- **语言**: Swift 5.0
- **UI 框架**: SwiftUI
- **最低系统**: iOS 15.0
- **网络请求**: URLSession (原生)
- **数据存储**: Keychain
- **API**: GitHub REST API v3
- **构建工具**: Xcode 15+

## 项目结构

```
GitHub/
├── GitHub/
│   ├── GitHubApp.swift          # 应用入口
│   ├── Info.plist               # 应用配置
│   ├── Assets.xcassets/         # 资源文件
│   ├── Core/
│   │   ├── Keychain/
│   │   │   └── TokenKeychain.swift    # Token 安全存储
│   │   ├── Network/
│   │   │   ├── GitHubAPI.swift        # GitHub API 封装
│   │   │   └── APIEndpoints.swift     # API 端点定义
│   │   └── Utils/
│   │       └── AppState.swift         # 全局状态管理
│   ├── Models/
│   │   ├── User.swift            # 用户模型
│   │   ├── Repository.swift      # 仓库模型
│   │   ├── FileItem.swift        # 文件模型
│   │   └── Commit.swift          # 提交模型
│   └── Views/
│       ├── Login/
│       │   └── LoginView.swift   # 登录页面
│       ├── Profile/
│       │   └── ProfileView.swift # 个人中心
│       ├── RepoList/
│       │   └── RepoListView.swift # 仓库列表
│       ├── FileBrowser/
│       │   └── FileBrowserView.swift # 文件浏览
│       └── CodeEditor/
│           └── CodeEditorView.swift  # 代码编辑器
├── GitHub.xcodeproj/             # Xcode 项目
├── .github/workflows/
│   └── build.yml                  # 自动构建工作流
└── README.md
```

## 快速开始

### 1. 获取 GitHub Token

1. 登录 GitHub 账号
2. 点击右上角头像 → **Settings**
3. 左侧菜单选择 **Developer settings**
4. 选择 **Personal access tokens** → **Tokens (classic)**
5. 点击 **Generate new token** → **Generate new token (classic)**
6. 填写 Note，设置过期时间
7. **勾选权限**：
   - `repo` (完整仓库访问权限，必需)
   - `user` (读取用户信息，必需)
8. 点击 **Generate token**
9. **立即复制保存 Token**（只显示一次）

### 2. 编译运行

#### 使用 Xcode（推荐）

1. 克隆项目到本地
2. 双击 `GitHub.xcodeproj` 打开项目
3. 选择你的开发团队（Signing & Capabilities）
4. 连接 iOS 设备或选择模拟器
5. 按 `Cmd + R` 运行

#### 使用 GitHub Actions 自动构建

1. Push 代码到 GitHub 仓库
2. 进入仓库的 **Actions** 页面
3. 等待 **Build iOS App** 工作流完成
4. 下载构建产物中的 `GitHub-iOS-IPA`
5. 使用自签名证书或 TrollStore 安装

### 3. 使用应用

1. 打开应用，在登录页输入你的 GitHub Token
2. 点击「立即登录」
3. 登录成功后即可浏览仓库、查看和编辑代码

## Token 权限说明

| 权限 | 说明 | 是否必需 |
|------|------|----------|
| `repo` | 完整仓库访问（读写） | ✅ 必需 |
| `repo:status` | 访问提交状态 | 包含在 repo |
| `repo_deployment` | 访问部署状态 | 包含在 repo |
| `public_repo` | 公开仓库访问 | 包含在 repo |
| `user` | 读取用户信息 | ✅ 必需 |
| `read:user` | 读取用户资料 | 包含在 user |

## 安全说明

- Token 仅存储在设备本地的 Keychain 中
- 不会上传到任何第三方服务器
- 应用卸载后 Token 自动清除
- 建议定期轮换 Token，设置合理的过期时间

## 项目文档

| 文档 | 说明 |
|------|------|
| [仓库环境配置手册](docs/repository-setup-guide.md) | 仓库目录结构、分支策略、CI环境配置、版本管理规范 |
| [流水线运维 & 故障排查文档](docs/pipeline-operations-guide.md) | 流水线架构、版本进位逻辑、常见故障排查、运维操作手册 |
| [制品说明文档](docs/artifact-guide.md) | IPA制品说明、SHA256校验方法、全能签导入指南、制品生命周期 |

## 更新日志

<!-- CHANGELOG_START -->

### v1.0.0 (2026-09-09)

- 🎉 首次发布
- ✅ Token 安全登录
- ✅ 仓库列表浏览与搜索
- ✅ 文件目录浏览
- ✅ 代码在线查看与编辑
- ✅ 提交修改到 GitHub
- ✅ 个人中心
- ✅ 分支切换
- ✅ 提交记录查看
- ✅ GitHub Actions 自动构建 IPA
- ✅ 企业级 CI/CD 流水线（版本自动递增、质量门禁、制品溯源）

<!-- CHANGELOG_END -->

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 免责声明

本项目仅供学习和个人使用，请遵守 GitHub 的使用条款。使用本应用进行的所有操作均由用户自行承担责任。
