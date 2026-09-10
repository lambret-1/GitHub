# 关于页面目录

本目录存放关于页面和镜像加速设置相关的视图文件。

## 文件说明

### AboutView.swift
**关于页面视图**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `appVersion` | 应用版本 | 当前应用的版本号 |
| `buildNumber` | 构建号 | 当前应用的构建号 |
| `showMirrorPicker` | 显示镜像选择器 | 控制镜像选择器页面的显示 |
| `showCheckUpdate` | 显示检查更新 | 控制检查更新弹窗的显示 |
| `isCheckingUpdate` | 检查更新中 | 检查更新进行中的状态标记 |
| `updateAvailable` | 有新版本 | 是否有可用的新版本 |
| `latestVersion` | 最新版本 | 最新版本号 |
| `isDownloading` | 下载中 | 更新包下载进行中的状态标记 |
| `downloadProgress` | 下载进度 | 更新包下载进度（0~1） |

**页面元素：**
- 应用图标（AppIconImage）
- 应用名称："GitHub 中文"
- 版本号和构建号
- 功能列表：
  - 镜像加速（尾部 > 符号）
  - 检查更新（尾部 > 符号）
  - 在 GitHub 查看主页（尾部 > 符号）

**检查更新功能：**
- 从 GitHub Releases 检查最新版本
- 有新版本时提示"立即下载"
- 下载完成后自动使用 iOS 原生分享功能
- 跳转至全能签或第三方签名应用进行安装
- 下载窗口统一白底黑字
- 更新下载不使用镜像，直接从官方下载（避免重定向问题）

**镜像加速功能：**
- 预设多个镜像站点
- 支持自定义镜像地址
- 镜像加速仅用于公开资源下载
- API 请求始终使用官方 GitHub 服务器
- 头像不经过镜像，直接从官方加载

---

### MirrorPickerView.swift
**镜像选择器视图**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `mirrors` | 预设镜像列表 | 预设的镜像站点数组 |
| `customMirrors` | 自定义镜像列表 | 用户添加的自定义镜像数组 |
| `selectedMirrorIndex` | 选中镜像索引 | 当前选中的镜像在列表中的索引 |
| `showAddCustomMirror` | 显示添加自定义镜像 | 控制添加自定义镜像弹窗的显示 |
| `customMirrorName` | 自定义镜像名称 | 用户输入的自定义镜像名称 |
| `customMirrorURL` | 自定义镜像地址 | 用户输入的自定义镜像地址 |

**预设镜像列表：**
1. 官方 API（https://api.github.com）
2. 清华大学镜像（https://mirrors.tuna.tsinghua.edu.cn/github-release）
3. 中科大镜像（https://mirrors.ustc.edu.cn/github-release）
4. 华为云镜像（https://mirrors.huaweicloud.com/repo）
5. 阿里云镜像（https://developer.aliyun.com/mirror）

**页面元素：**
- 镜像列表（每个镜像显示：名称、地址、选中标记）
- 添加自定义镜像按钮
- 自定义镜像也显示在列表中

**镜像选择：**
- 点击镜像：选中该镜像
- 选中项显示勾选标记
- 官方镜像在列表中过滤显示（API 不使用镜像）
- 镜像选择后立即生效

**自定义镜像：**
- 输入镜像名称和地址
- 点击添加按钮确认添加
- 添加后显示在镜像列表中
- 支持选择已添加的自定义镜像
- 修复变量名冲突问题

**镜像加速生效范围：**
- 文件下载
- HTML 网页预览
- 浏览器打开 GitHub 链接
- 不包括：API 请求、头像加载、更新下载
