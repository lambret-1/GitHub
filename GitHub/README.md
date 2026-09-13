# GitHub 中文 iOS 客户端

纯原生 SwiftUI 开发的 GitHub iOS 客户端，支持 Token 登录、仓库/文件浏览、代码编辑、上传下载、账号管理、代码查找高亮、暗黑模式、HTML 网页预览、镜像加速、搜索功能、GitHub Actions 管理、提交记录、Issues/PR管理、星标收藏等功能。

## 项目结构

```
GitHub/
├── Assets.xcassets/          # 资源文件目录（图标、颜色等）
├── Core/                     # 核心功能目录
│   ├── Keychain/             # 钥匙串管理
│   ├── Network/              # 网络请求层
│   └── Utils/                # 工具类
├── Models/                   # 数据模型目录
├── Views/                    # 视图层目录
│   ├── About/                # 关于页面
│   ├── Actions/              # Actions 管理页面
│   ├── CodeEditor/           # 代码编辑器
│   ├── Commits/              # 提交记录模块
│   ├── Components/           # 通用组件
│   ├── FileBrowser/          # 文件浏览器
│   ├── Issues/               # Issues管理页面
│   ├── Login/                # 登录页面
│   ├── Profile/              # 个人中心
│   ├── PullRequests/         # Pull Requests管理页面
│   ├── RepoList/             # 仓库列表（含星标收藏）
│   ├── Search/               # 搜索页面
│   ├── Settings/             # 仓库设置页面
│   ├── Shared/               # 共享组件
│   └── README.md             # 视图层说明文档
├── GitHubApp.swift           # 应用入口
├── Info.plist                # 应用配置文件
└── README.md                 # 本文件
```

## 文件说明

### GitHubApp.swift
**应用入口文件**

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `@main` | 应用入口标记 | SwiftUI 应用入口标记 |
| `AppState` | 应用状态 | 全局应用状态管理（暗黑模式、当前用户等） |
| `AccountManager` | 账号管理器 | 多账号管理和切换 |
| `AppSettings` | 应用设置 | 镜像加速等应用设置 |

---

### Info.plist
**应用配置文件**

**功能参数说明：**

| 键名 | 中文释义 | 说明 |
|------|---------|------|
| `CFBundleDisplayName` | 应用显示名称 | "GitHub 中文" |
| `CFBundleShortVersionString` | 版本号 | 三段式语义版本（主.次.补丁） |
| `CFBundleVersion` | 构建号 | 应用构建版本号 |
| `LSRequiresIPhoneOS` | 仅iOS运行 | 应用仅在 iOS 设备上运行 |
| `UIApplicationSceneManifest` | 场景清单 | 应用场景配置 |
| `UILaunchScreen` | 启动画面 | 应用启动画面配置 |
| `UISupportedInterfaceOrientations` | 支持方向 | 支持的界面方向（竖屏） |
| `NSAppTransportSecurity` | 网络安全策略 | 应用传输安全配置 |

---

## 技术栈

- **语言**: Swift 5.9
- **框架**: SwiftUI
- **最低系统**: iOS 16.0
- **构建工具**: Xcode 15.4 + XcodeGen
- **CI/CD**: GitHub Actions

## 核心功能

1. **Token 登录** - 使用 GitHub Personal Access Token 登录，支持暗黑风格动画特效
2. **仓库管理** - 查看、搜索仓库，支持高级筛选
3. **星标收藏** - 星标仓库列表，支持搜索、筛选、排序、左滑取消星标、重按菜单，星标按钮带动画效果
4. **文件浏览** - 浏览仓库文件和文件夹，支持下拉刷新、路径导航
5. **代码编辑** - 高性能代码编辑器，语法高亮，行号显示，查找替换，双指缩放，大文件流畅打开
6. **文件操作** - 上传、下载、创建、删除、重命名文件和文件夹
7. **账号管理** - 多账号添加、切换、删除
8. **代码查找** - 代码内查找高亮，上一个/下一个导航，选中文字查找
9. **暗黑模式** - 我的 > 头像双击切换
10. **HTML 预览** - 网页文件在线预览，支持刷新
11. **镜像加速** - 国内访问 GitHub 加速，支持自定义镜像
12. **搜索功能** - 仓库搜索和用户搜索，支持高级筛选，仓库代码搜索
13. **Actions 管理** - 查看工作流、运行记录、作业日志，触发/取消/重新运行，工作流编辑器
14. **提交记录** - 仓库提交历史列表、提交详情、文件Diff对比，支持大文件流畅渲染、双指缩放
15. **Issues管理** - 仓库Issues列表和详情，支持状态筛选、新建Issue
16. **Pull Requests管理** - 仓库PR列表和详情，支持状态筛选、新建PR
17. **仓库设置** - 查看仓库设置和统计信息
18. **自动更新** - 检查更新、下载IPA、自动唤醒iOS分享功能安装
19. **README展示** - 获取Markdown原文并渲染，对齐GitHub官方样式

## 构建说明

项目使用 XcodeGen 管理项目配置，CI 流水线自动构建。

```bash
# 生成 Xcode 项目
xcodegen generate

# 编译
xcodebuild -project GitHub.xcodeproj -scheme GitHub -configuration Release build
```

## 版本规范

- 采用三段式语义版本：`主版本.次版本.补丁号`
- 补丁号范围 0~9，自动进位
- 示例：1.0.9 → 1.1.0；1.9.9 → 2.0.0
- 版本号由 CI 流水线自动递增

## CI/CD 流水线

项目使用 GitHub Actions 进行自动化构建，包含以下 Job：

1. **版本计算与单元测试** - 版本号自动递增、版本进位逻辑单元测试
2. **Xcode编译与IPA导出** - Xcode编译、导出未签名IPA、计算SHA256哈希、生成制品元数据
3. **更新README更新日志** - 自动在README顶部插入新版日志
4. **清理过期Artifacts** - 自动清理旧版本Actions Artifacts

所有CI脚本和workflow文件均托管在仓库 `.github/workflows/` 和 `scripts/` 目录下。
