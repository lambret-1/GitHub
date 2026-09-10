# 工具类目录

本目录存放应用的各种工具类，包括应用状态管理、账号管理、应用设置、版本信息、文件下载、图片缓存、最后提交时间缓存等。

## 文件说明

### AppState.swift
**应用状态管理类** - ObservableObject，全局应用状态

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `isDarkMode` | 暗黑模式开关 | 控制应用是否使用暗黑模式，UserDefaults 持久化 |
| `isLoggedIn` | 登录状态 | 标记用户是否已登录 |
| `currentUser` | 当前用户 | 当前登录的用户信息 |
| `objectWillChange` | 对象变更发布者 | ObservableObject 协议要求的发布者 |

**使用方法：**
- 我的 > 头像双击切换暗黑模式
- 状态变更自动持久化到 UserDefaults
- 应用启动时从 UserDefaults 恢复状态

---

### AccountManager.swift
**账号管理器类** - ObservableObject，多账号管理

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `accounts` | 账号列表 | 所有已添加的账号数组 |
| `currentAccount` | 当前账号 | 当前选中的账号 |
| `addAccount(token:)` | 添加账号 | 使用 Token 添加新账号，自动获取用户信息 |
| `switchAccount(_:)` | 切换账号 | 切换到指定账号，更新 Token 和用户信息 |
| `removeAccount(_:)` | 删除账号 | 删除指定账号，清除相关数据 |
| `loadAccounts()` | 加载账号 | 从本地存储加载所有账号 |
| `saveAccounts()` | 保存账号 | 保存所有账号到本地存储 |

**账号数据结构：**
- Token：GitHub Personal Access Token
- 用户名：GitHub 登录名
- 头像 URL：用户头像地址
- 添加时间：账号添加时间戳

---

### AppSettings.swift
**应用设置管理器类** - ObservableObject，镜像加速等设置

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `mirrors` | 镜像列表 | 预设的镜像站点列表 |
| `customMirrors` | 自定义镜像列表 | 用户添加的自定义镜像 |
| `selectedMirrorIndex` | 选中镜像索引 | 当前选中的镜像在列表中的索引 |
| `currentMirror` | 当前镜像 | 当前选中的镜像配置（计算属性） |
| `addCustomMirror(name:url:)` | 添加自定义镜像 | 添加用户自定义的镜像站点 |
| `removeCustomMirror(at:)` | 删除自定义镜像 | 删除指定的自定义镜像 |
| `convertURL(_:)` | 转换 URL | 将 GitHub URL 转换为镜像 URL |
| `convertWebURL(_:)` | 转换网页 URL | 将 GitHub 网页 URL 转换为镜像 URL |
| `convertRawURL(_:)` | 转换 Raw URL | 将 GitHub Raw 文件 URL 转换为镜像 URL |

**预设镜像列表：**
1. 官方 API（https://api.github.com）
2. 清华大学镜像（https://mirrors.tuna.tsinghua.edu.cn/github-release）
3. 中科大镜像（https://mirrors.ustc.edu.cn/github-release）
4. 华为云镜像（https://mirrors.huaweicloud.com/repo）
5. 阿里云镜像（https://developer.aliyun.com/mirror）

**镜像加速安全策略：**
- API 请求（需要认证的）始终使用官方 GitHub 服务器
- 镜像加速仅用于文件下载、HTML 预览、头像加载、浏览器打开等公开资源
- 头像不经过镜像，直接从官方加载
- 更新下载不使用镜像，直接从官方下载（避免重定向问题）

---

### AppVersion.swift
**版本信息工具类**

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `currentVersion` | 当前版本号 | 从 Info.plist 读取的应用版本号 |
| `buildNumber` | 构建号 | 从 Info.plist 读取的应用构建号 |
| `fullVersionString` | 完整版本字符串 | 版本号 + 构建号的完整字符串 |
| `checkForUpdate(completion:)` | 检查更新 | 从 GitHub Releases 检查是否有新版本 |
| `downloadUpdate(url:completion:)` | 下载更新 | 下载新版本 IPA 文件 |

**版本号格式：**
- 三段式语义版本：`主版本.次版本.补丁号`
- 示例：2.0.5
- 补丁号范围 0~9，自动进位

---

### FileDownloadManager.swift
**文件下载管理工具类**

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `shared` | 单例实例 | FileDownloadManager 共享单例 |
| `downloadFile(url:completion:)` | 下载文件 | 从指定 URL 下载文件，支持镜像加速 |
| `downloadFileWithProgress(url:progressHandler:completion:)` | 带进度下载 | 下载文件并实时返回下载进度 |
| `cancelDownload(url:)` | 取消下载 | 取消指定 URL 的下载任务 |
| `DownloadDelegate` | 下载代理 | 自定义 URLSessionDownloadDelegate，处理下载进度和完成回调 |
| `useMirror` | 使用镜像 | 下载参数，控制是否走镜像加速 |

**下载完成后处理：**
- 保存到临时目录
- 计算文件 SHA256 哈希
- 自动弹出 iOS 原生分享面板
- 跳转至全能签或第三方签名应用进行安装

---

### ImageCache.swift
**图片缓存类** - 内存 + 磁盘双层缓存

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `shared` | 单例实例 | ImageCache 共享单例 |
| `memoryCache` | 内存缓存 | NSCache 实现的内存缓存，快速访问 |
| `diskCachePath` | 磁盘缓存路径 | 磁盘缓存的存储目录路径 |
| `cacheExpiryInterval` | 缓存过期时间 | 缓存保留时间，默认 1 天（86400 秒） |
| `getImage(for:completion:)` | 获取图片 | 从缓存获取图片，缓存未命中时从网络下载 |
| `setImage(_:for:)` | 设置图片 | 将图片存入内存和磁盘缓存 |
| `removeImage(for:)` | 移除图片 | 从缓存中移除指定图片 |
| `clearCache()` | 清除缓存 | 清除所有内存和磁盘缓存 |
| `clearExpiredCache()` | 清除过期缓存 | 清除超过过期时间的磁盘缓存 |
| `cleanupCacheIfNeeded()` | 按需清理缓存 | 检查并清除过期缓存（不包含删除 token） |

**缓存策略：**
- 内存缓存：使用 NSCache，自动响应内存警告
- 磁盘缓存：保存到 Library/Caches 目录
- 缓存有效期：1 天（24 小时）
- 缓存键：使用图片 URL 的 MD5 哈希
- 应用启动时自动清理过期缓存

---

### LastCommitCache.swift
**最后编辑时间缓存类**

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `shared` | 单例实例 | LastCommitCache 共享单例 |
| `cache` | 缓存字典 | 内存缓存字典，键为文件路径，值为提交信息 |
| `getLastCommit(for:completion:)` | 获取最后提交 | 从缓存获取文件的最后提交信息，缓存未命中时从 API 获取 |
| `setLastCommit(_:for:)` | 设置最后提交 | 将文件的最后提交信息存入缓存 |
| `clearCache()` | 清除缓存 | 清除所有缓存 |
| `cacheKey(owner:repo:path:branch:)` | 缓存键生成 | 生成文件的唯一缓存键 |

**缓存用途：**
- 文件列表中显示文件的最后编辑时间
- 减少重复的 API 请求
- 提升文件列表加载速度

---

## 工具类规范

1. 单例类必须使用 `static let shared` 定义
2. 状态管理类必须遵循 ObservableObject 协议
3. 缓存类必须实现内存和磁盘双层缓存
4. 缓存必须设置过期时间，避免无限增长
5. 网络请求完成后必须在主线程回调
6. 错误处理必须完善，避免崩溃
7. 用户设置必须持久化到 UserDefaults 或 Keychain
