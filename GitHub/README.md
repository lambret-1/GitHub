# GitHub 中文 iOS 客户端

纯原生 SwiftUI 开发的 GitHub iOS 客户端，支持 Token 登录、仓库/文件浏览、代码编辑、上传下载、账号管理、代码查找高亮、暗黑模式、HTML 网页预览、镜像加速、搜索功能、GitHub Actions 管理等功能。

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
│   ├── Components/           # 通用组件
│   ├── FileBrowser/          # 文件浏览器
│   ├── Login/                # 登录页面
│   ├── Profile/              # 个人中心
│   ├── RepoList/             # 仓库列表
│   └── Search/               # 搜索页面
├── GitHubApp.swift           # 应用入口
└── Info.plist                # 应用配置文件
```

## 文件说明

### GitHubApp.swift
**应用入口文件**

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `@main` | 应用入口标记 | SwiftUI 应用入口标记 |
| `AppState` | 应用状态 | 全局应用状态管理（暗黑模式等） |
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

1. **Token 登录** - 使用 GitHub Personal Access Token 登录
2. **仓库管理** - 查看、搜索仓库，支持高级筛选
3. **文件浏览** - 浏览仓库文件和文件夹，支持下拉刷新
4. **代码编辑** - 高性能代码编辑器，语法高亮，行号显示，查找替换
5. **文件操作** - 上传、下载、创建、删除、重命名文件和文件夹
6. **账号管理** - 多账号添加、切换、删除
7. **代码查找** - 代码内查找高亮，上一个/下一个导航
8. **暗黑模式** - 我的 > 头像双击切换
9. **HTML 预览** - 网页文件在线预览，支持刷新
10. **镜像加速** - 国内访问 GitHub 加速，支持自定义镜像
11. **搜索功能** - 仓库搜索和用户搜索，支持高级筛选
12. **Actions 管理** - 查看工作流、运行记录、作业日志，触发/取消/重新运行

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
