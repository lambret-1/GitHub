# 代码编辑器页面目录

本目录存放代码编辑器相关的视图文件，包括高性能代码编辑器、语法高亮、行号显示等。

## 文件说明

### CodeEditorView.swift
**代码编辑器主视图**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `owner` | 仓库所有者 | GitHub 用户名或组织名 |
| `repo` | 仓库名称 | GitHub 仓库名称 |
| `path` | 文件路径 | 编辑的文件在仓库中的路径 |
| `branch` | 分支名 | 文件所在的分支 |
| `fileName` | 文件名 | 编辑的文件名 |
| `autoEnterEditMode` | 自动进入编辑模式 | 是否自动进入编辑模式（从重按菜单编辑文件时使用） |
| `content` | 文件内容 | 当前编辑的文件内容 |
| `originalContent` | 原始内容 | 文件加载时的原始内容，用于比较是否修改 |
| `isEditing` | 编辑模式 | 是否处于编辑模式 |
| `isLoading` | 加载状态 | 文件内容加载中的状态标记 |
| `isSaving` | 保存中状态 | 文件保存提交中的状态标记 |
| `errorMessage` | 错误信息 | 加载或保存失败时的错误提示 |
| `fileSha` | 文件哈希 | 文件的 Git SHA 哈希值，用于更新文件 |
| `fontSize` | 字体大小 | 代码编辑器字体大小（默认 10） |
| `searchText` | 搜索文本 | 查找功能的搜索关键词 |
| `showSearchBar` | 显示搜索栏 | 控制查找栏的显示 |
| `currentMatchIndex` | 当前匹配索引 | 当前高亮的匹配项索引 |
| `totalMatches` | 总匹配数 | 搜索结果的总匹配数 |

**编辑模式保护：**
- 进入编辑模式禁用手势返回
- 进入编辑模式禁用返回按键
- 进入编辑模式禁用底部 Tab 栏切换
- 退出编辑模式自动恢复所有功能

**编辑模式 UI：**
- 底部工具栏（取消、提交修改按钮）
- 底部工具栏不允许跟随键盘移动
- 隐藏文件大小和时间行
- 编辑模式行高减少一半
- 行号列宽自适应宽度

**查找功能：**
- 查找栏（搜索输入框、上一个、下一个按钮）
- 搜索结果计数（当前/总数）
- 匹配项高亮显示
- 上一个/下一个按钮位置符合右手操作
- 按钮背景色浅色系搭配

**提交修改：**
- 取消和提交修改按钮增加二次确认
- 提交时调用 GitHub API 更新文件
- 提交成功后退出编辑模式

---

### CodeTextView.swift
**高性能代码编辑器组件**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `text` | 文本内容 | 编辑器的文本内容（双向绑定） |
| `fontSize` | 字体大小 | 编辑器字体大小 |
| `isEditable` | 是否可编辑 | 控制编辑器是否可编辑 |
| `onTextChange` | 文本变更回调 | 文本内容变更时的回调 |

**技术实现：**
- 基于原生 UITextView 封装
- 支持大文件顺畅打开（1MB 以上）
- 自定义 CodeEditorTextView 类
- 重写 canPerformAction 添加"🔍查找"菜单项
- 选中文字后菜单显示查找选项
- 支持双指放大缩小字体
- 光标跟随滚动

---

### LineNumberLayoutManager.swift
**自定义行号绘制 LayoutManager**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `lineNumberFont` | 行号字体 | 行号显示的字体 |
| `lineNumberColor` | 行号颜色 | 行号文本的颜色 |
| `lineNumberBackgroundColor` | 行号背景色 | 行号区域的背景颜色 |
| `lineNumberWidth` | 行号宽度 | 行号区域的宽度（自适应） |

**技术实现：**
- 继承 NSLayoutManager
- 重写 drawBackground 方法绘制行号
- 使用 enumerateLineFragments 获取每行的位置
- 行号与文本行精确对齐
- 行号列宽自适应内容宽度
- 支持大文件流畅滚动

---

### SyntaxHighlighter.swift
**语法高亮器**

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `highlight(_:language:)` | 高亮代码 | 对指定语言的代码进行语法高亮 |
| `keywords` | 关键字集合 | 各编程语言的关键字集合 |
| `keywordColor` | 关键字颜色 | 关键字的高亮颜色 |
| `stringColor` | 字符串颜色 | 字符串字面量的高亮颜色 |
| `commentColor` | 注释颜色 | 注释的高亮颜色 |
| `numberColor` | 数字颜色 | 数字字面量的高亮颜色 |
| `functionColor` | 函数名颜色 | 函数名的高亮颜色 |
| `typeColor` | 类型颜色 | 类型名的高亮颜色 |

**支持的语言：**
- Swift
- Objective-C
- Python
- JavaScript
- TypeScript
- Java
- Kotlin
- Go
- Rust
- C/C++
- Ruby
- PHP
- HTML
- CSS
- Shell
- Markdown
- JSON
- YAML

**高亮元素：**
- 关键字（if、else、func、class 等）
- 字符串（双引号、单引号包裹的内容）
- 注释（单行注释、多行注释）
- 数字（整数、浮点数、十六进制）
- 函数名（函数定义和调用）
- 类型名（类、结构体、枚举名）
