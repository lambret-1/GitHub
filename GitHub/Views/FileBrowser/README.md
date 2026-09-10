# 文件浏览器页面目录

本目录存放仓库文件浏览和操作相关的视图文件。

## 文件说明

### FileBrowserView.swift
**文件浏览器主视图**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `repository` | 仓库信息 | 当前浏览的仓库数据模型 |
| `currentPath` | 当前路径 | 当前浏览的目录路径 |
| `files` | 文件列表 | 当前目录下的文件和文件夹数组 |
| `selectedBranch` | 选中分支 | 当前选中的分支名 |
| `isLoading` | 加载状态 | 文件列表加载中的状态标记 |
| `isUploading` | 上传中状态 | 文件上传进行中的状态标记 |
| `isDownloading` | 下载中状态 | 文件下载进行中的状态标记 |
| `isDeleteMode` | 删除模式 | 是否处于多选删除模式 |
| `selectedFilesForDelete` | 选中删除的文件 | 多选删除模式下选中的文件数组 |
| `showDocumentPicker` | 显示文件选择器 | 控制文档选择器的显示 |
| `showCreateFileDialog` | 显示新建文件对话框 | 控制新建文件对话框的显示 |
| `showCreateFolderDialog` | 显示创建文件夹对话框 | 控制创建文件夹对话框的显示 |
| `showBranchPicker` | 显示分支选择器 | 控制分支选择器的显示 |
| `showCommits` | 显示提交记录 | 控制提交记录页面的显示 |
| `showActions` | 显示 Actions | 控制 Actions 页面的显示 |
| `showHTMLPreview` | 显示 HTML 预览 | 控制 HTML 网页预览的显示 |
| `newFileName` | 新文件名 | 新建文件时输入的文件名 |
| `newFolderName` | 新文件夹名 | 创建文件夹时输入的文件夹名 |

**三个点菜单功能：**
- 上传文件
- 新建文件
- 创建文件夹
- 删除文件（多选删除模式）
- 切换分支
- 提交记录
- Actions
- 在 GitHub 打开

**文件操作：**
- 点击文件：打开文件（代码编辑器或 HTML 预览）
- 点击文件夹：进入文件夹
- 长按文件：弹出上下文菜单（编辑文件、重命名、复制 Raw 地址、下载该文件、HTML 网页查看器、删除）
- 下拉刷新：重新加载当前目录

**文件列表显示：**
- 文件/文件夹图标
- 文件名
- 文件大小（文件）
- 最后编辑时间（带灰色历史图标）

---

### CreateFileView.swift
**新建文件视图**

**功能参数说明：**
- 文件名输入框
- 创建按钮（确认创建）
- 取消按钮
- 创建成功后自动跳转到编辑状态

---

### CreateFolderView.swift
**创建文件夹视图**

**功能参数说明：**
- 文件夹名输入框
- 创建按钮（确认创建）
- 取消按钮

---

### DocumentPickerView.swift
**文件选择器视图**

**功能参数说明：**
- 基于 UIDocumentPickerViewController 封装
- 支持多选或单选文件
- 选择文件后自动跳过确认步骤
- 最后统一确认上传
- 支持文件类型过滤

---

### HTMLPreviewView.swift
**HTML 网页预览视图**

**功能参数说明：**
- 基于 WKWebView 渲染 HTML 内容
- 顶部工具栏左侧刷新按钮
- 加载进度提示
- 缓存机制（5 分钟有效期，空内容不缓存）
- 支持镜像加速加载
- 加载失败错误提示

**使用场景：**
- 预览仓库中的 HTML 文件
- 渲染 Markdown 转换后的 HTML
- 查看网页效果
