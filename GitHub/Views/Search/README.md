# 搜索页面目录

本目录存放搜索功能相关的视图文件，包括仓库搜索、用户搜索和高级筛选。

## 文件说明

### SearchView.swift
**搜索主视图**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `selectedTab` | 选中标签 | 当前选中的搜索类型（仓库/用户） |
| `searchText` | 搜索文本 | 搜索输入框的文本内容 |
| `repos` | 仓库结果 | 仓库搜索结果数组 |
| `users` | 用户结果 | 用户搜索结果数组 |
| `isLoading` | 加载状态 | 搜索请求进行中的状态标记 |
| `errorMessage` | 错误信息 | 搜索失败时的错误提示文本 |
| `currentPage` | 当前页码 | 分页加载的当前页码 |
| `hasMoreResults` | 有更多结果 | 是否还有更多搜索结果可加载 |
| `showAdvancedFilter` | 显示高级筛选 | 控制高级筛选面板的显示 |
| `repoFilter` | 仓库筛选条件 | 仓库搜索的高级筛选条件（RepoFilterState） |
| `userFilter` | 用户筛选条件 | 用户搜索的高级筛选条件（UserFilterState） |

**搜索类型：**
- 仓库搜索：搜索 GitHub 仓库
- 用户搜索：搜索 GitHub 用户

**页面元素：**
- 搜索输入框（支持实时搜索）
- 标签切换（仓库/用户）
- 高级筛选按钮（有激活筛选时显示蓝色和角标）
- 筛选条件标签（横向滚动显示激活的筛选条件）
- 搜索结果列表（支持下拉刷新、分页加载）
- 一键清除筛选条件按钮

**搜索结果展示：**
- 仓库结果：仓库名、描述、主要语言、Star 数、Fork 数
- 用户结果：用户名、头像、显示名称、仓库数、关注者数

**高级筛选集成：**
- 搜索时自动应用筛选条件构建查询字符串
- 加载更多时保持筛选条件
- 筛选条件变更后自动重新搜索

---

### AdvancedFilterView.swift
**高级筛选面板视图**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `repoFilter` | 仓库筛选条件 | 仓库搜索的筛选条件（双向绑定） |
| `userFilter` | 用户筛选条件 | 用户搜索的筛选条件（双向绑定） |
| `selectedTab` | 选中标签 | 当前选中的搜索类型 |
| `onApply` | 应用回调 | 点击应用按钮时的回调 |
| `onReset` | 重置回调 | 点击重置按钮时的回调 |

**仓库筛选条件：**
- 搜索范围：仓库名称、仓库描述、README 文件
- 仓库属性：仅公开仓库、仅私有仓库、归档状态、模板仓库
- 编程语言：选择编程语言（LanguagePickerView）
- 主题与许可证：主题输入、许可证选择（LicensePickerView）
- 所有者：用户、组织
- 数值范围：最少 Star 数、最少 Fork 数、最小大小
- 时间范围：创建时间、最近推送时间

**用户筛选条件：**
- 搜索范围：用户名、全名、邮箱
- 用户类型：用户/组织
- 位置与语言：位置输入、主要语言选择
- 数值范围：最少仓库数、最少关注者、最少关注数
- 时间范围：注册时间

**辅助方法：**
- `optionalIntBinding`：可选 Int 类型的 Binding
- `optionalStringBinding`：可选 String 类型的 Binding
- `triStateBinding`：三态 Bool? 类型的 Binding

**LanguagePickerView（语言选择器）：**
- 列表形式展示常用编程语言
- 支持选择"不限"
- 选中项显示勾选标记

**LicensePickerView（许可证选择器）：**
- 列表形式展示常用开源许可证
- 支持选择"不限"
- 选中项显示勾选标记

---

### FilterState.swift
**筛选条件模型文件**

**功能参数说明：**

**RepoFilterState（仓库筛选条件）：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `searchInName` | 搜索名称 | 是否在仓库名称中搜索 |
| `searchInDescription` | 搜索描述 | 是否在仓库描述中搜索 |
| `searchInReadme` | 搜索 README | 是否在 README 文件中搜索 |
| `isPublic` | 仅公开 | 仅搜索公开仓库 |
| `isPrivate` | 仅私有 | 仅搜索私有仓库 |
| `isArchived` | 归档状态 | 归档状态筛选（nil/true/false） |
| `isTemplate` | 模板仓库 | 模板仓库筛选（nil/true/false） |
| `language` | 编程语言 | 筛选的编程语言（可选） |
| `topic` | 主题 | 筛选的主题标签（可选） |
| `license` | 许可证 | 筛选的开源许可证（可选） |
| `user` | 用户 | 仓库所有者用户名（可选） |
| `org` | 组织 | 仓库所有者组织名（可选） |
| `minStars` | 最少 Star 数 | 仓库最少 Star 数量（可选） |
| `minForks` | 最少 Fork 数 | 仓库最少 Fork 数量（可选） |
| `minSizeKB` | 最小大小 | 仓库最小大小（KB）（可选） |
| `createdAfter` | 创建时间之后 | 仓库创建时间不早于此日期（可选） |
| `pushedAfter` | 推送时间之后 | 仓库最近推送时间不早于此日期（可选） |
| `hasFilters` | 有筛选条件 | 计算属性，判断是否有激活的筛选条件 |
| `buildQuery(baseQuery:)` | 构建查询 | 方法，根据筛选条件构建 GitHub 搜索查询字符串 |
| `reset()` | 重置 | 方法，重置所有筛选条件为默认值 |

**UserFilterState（用户筛选条件）：**

| 属性名 | 中文释义 | 说明 |
|--------|---------|------|
| `searchInLogin` | 搜索用户名 | 是否在用户名中搜索 |
| `searchInFullName` | 搜索全名 | 是否在用户全名中搜索 |
| `searchInEmail` | 搜索邮箱 | 是否在用户邮箱中搜索 |
| `userType` | 用户类型 | 用户类型筛选（用户/组织）（可选） |
| `location` | 位置 | 用户地理位置筛选（可选） |
| `language` | 主要语言 | 用户主要编程语言筛选（可选） |
| `minRepos` | 最少仓库数 | 用户最少仓库数量（可选） |
| `minFollowers` | 最少关注者 | 用户最少关注者数量（可选） |
| `minFollowing` | 最少关注数 | 用户最少关注数量（可选） |
| `createdAfter` | 注册时间之后 | 用户注册时间不早于此日期（可选） |
| `hasFilters` | 有筛选条件 | 计算属性，判断是否有激活的筛选条件 |
| `buildQuery(baseQuery:)` | 构建查询 | 方法，根据筛选条件构建 GitHub 搜索查询字符串 |
| `reset()` | 重置 | 方法，重置所有筛选条件为默认值 |

**UserType（用户类型枚举）：**
- `user`：普通用户
- `organization`：组织

**FilterOptions（筛选选项数据）：**
- `languages`：常用编程语言列表
- `licenses`：常用开源许可证列表
- `starOptions`：Star 数选项
- `forkOptions`：Fork 数选项
- `repoOptions`：仓库数选项
- `followerOptions`：关注者数选项
