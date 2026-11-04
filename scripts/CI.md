# CI 与 UI 自动化测试基础设施

## 工具链

| 项目 | 版本 |
| --- | --- |
| GitHub Actions Runner | macOS 14 |
| Xcode | 15.4 |
| Swift | 5.10（随 Xcode 15.4 提供） |
| XcodeGen | 2.46.0 |
| SwiftLint | 0.65.1 |
| iOS Deployment Target | 16.0 |

## 测试 Target

XcodeGen 通过 `project.yml` 声明三个 Target：

- `GitHub`：iOS 主应用。
- `GitHubTests`：单元测试。
- `GitHubUITests`：iOS Simulator UI 自动化测试。

`GitHub` Scheme 同时包含 XCTest 与 XCUITest，并启用代码覆盖率收集。

## UI 测试隔离约定

UI 测试启动应用时必须同时设置：

- 启动参数：`-ui-testing`
- 启动环境变量：`UI_TESTING=1`

应用检测到 UI 测试模式后：

1. 不读取 Keychain 登录状态，不恢复或删除真实账号凭据。
2. 拦截登录、用户信息、版本检查和更新下载请求，不访问真实 GitHub API。
3. 不安装崩溃日志处理器。
4. 使用固定的浅色模式初始状态，不读取或写入持久化主题及提醒偏好。
5. 跳过分享文件扫描等启动副作用。

每个 UI 测试在结束时终止被测应用，避免测试实例跨用例残留。CI 禁用 Xcode 测试并行执行，避免模拟器和共享持久化状态造成竞争。

## 本地执行

```bash
brew install xcodegen swiftlint
./scripts/ci-swiftlint.sh
./scripts/ci-bootstrap.sh
xcodebuild test \
  -project GitHub.xcodeproj \
  -scheme GitHub \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath TestResults.xcresult \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

## GitHub Actions

统一入口：`.github/workflows/ci-orchestrator.yml`

执行顺序：

1. SwiftLint 与 Bootstrap 在独立 Job 中并行执行。
2. Bootstrap 使用 XcodeGen 生成并验证工程，通过短期 Artifact 将工程传递给测试 Job。
3. 两个质量门禁全部成功后，检查 iPhone 15 模拟器并执行 XCTest。
4. XCTest 成功后，串行执行 XCUITest。
5. 无论测试成功或失败，上传 XCTest/XCUITest Result Bundle（若已生成）。
6. Summary 汇总事件、ref、commit SHA 与各阶段结果。

## 当前阶段验收范围

第五阶段 5.1 已完成测试基础设施与隔离机制验收：Target/Scheme 配置、UI 测试启动约定、持久化状态隔离、应用生命周期清理，以及 CI 的非并行模拟器执行。

第五阶段 5.2 扩展登录流程 UI 自动化覆盖：

- 登录页关键控件与空输入禁用状态。
- Token 输入、清空及按钮状态联动。
- 仅包含空白字符的 Token 必须显示本地校验错误。
- UI 测试模式下提交 Token 必须显示拦截提示，不访问真实 API。
- 登录失败后保持未登录；应用重启后仍显示初始登录页，且不保留错误态或测试 Token。
- Token 错误提示提供稳定的 Accessibility Identifier，供自动化测试读取。

所有登录流程 UI 测试必须继续使用 `-ui-testing` 与 `UI_TESTING=1`，不得在自动化测试中使用真实凭据或访问真实 GitHub 服务。

第五阶段 5.3 扩展主界面导航自动化覆盖：

- 使用额外启动参数 `-ui-testing-authenticated` 进入隔离的已登录界面壳层。
- 该模式仅将内存态 `isLoggedIn` 设为 true，不读取真实账号、Keychain 或用户信息。
- 仓库页在 UI 测试模式下跳过 `AccountManager` 持久化账号监听与仓库 API 请求，显示本地空状态。
- 验证主界面“仓库”和“我的”Tab 均存在，仓库页显示本地空状态，并可切换到“我的”导航页面。
- 该启动参数只在 UI 测试模式下生效，不改变正常启动和生产登录行为。


第五阶段 5.4 扩展仓库列表交互自动化覆盖：

- 通过仅在 UI 测试启动参数启用的本地 fixture 验证列表交互，不请求真实 GitHub API。
- 验证按仓库名称搜索、私有/公开筛选、搜索与筛选组合，以及无匹配结果的空状态。
- 为搜索输入框、筛选控件和仓库行提供稳定的 Accessibility Identifier。
- fixture 仅在同时启用 UI 测试模式与 `-ui-testing-repository-fixtures` 时加载，不影响正常运行和 5.3 的空状态测试。


第五阶段 5.5 扩展星标仓库列表自动化覆盖：

- 使用 `-ui-testing-starred-fixtures` 加载固定的本地星标仓库，不读取真实星标列表、不调用 GitHub API。
- 验证星标仓库列表初始展示、自己的/别人的筛选、按仓库描述搜索和无匹配空状态。
- 搜索框、筛选按钮、星标仓库行及入口提供稳定的 Accessibility Identifier。
- UI 测试模式下跳过星标列表网络加载、下拉刷新和分页请求；正常运行逻辑保持不变。


第五阶段 5.6 扩展个人中心页面 UI 自动化覆盖：

- 使用 `-ui-testing-profile-fixtures` 注入固定的本地用户资料，仅在 UI 测试且隔离登录模式下生效。
- 验证个人资料名称、用户名、简介和统计数据展示。
- 验证个人中心“关于”页面导航与返回，以及退出确认取消行为。
- 为个人资料关键字段及页面入口提供稳定的 Accessibility Identifier。
- 测试 fixture 不读取真实账号凭据、不触发个人资料网络请求；正常运行行为保持不变。


第五阶段 5.7 扩展多账号管理 UI 自动化覆盖：

- UI 测试模式注入三个内存账号，初始化时不读取账号 UserDefaults。
- 测试模式下账号新增、删除、切换仅更新内存状态，不写入 UserDefaults 或 Keychain。
- 验证当前账号与其他账号展示、切换账号、删除非当前账号。
- 验证添加账号表单打开和取消流程，不提交真实 Token、不访问 GitHub API。
- 为账号管理入口、账号行、切换/删除、添加和取消按钮增加 Accessibility Identifier。


第五阶段 5.8 扩展仓库详情与文件浏览 UI 自动化覆盖：

- 使用 `-ui-testing-filebrowser-fixtures` 加载固定目录树，不请求真实 GitHub API。
- 验证仓库详情页根目录文件、目录进入、多级目录导航和面包屑返回。
- UI 测试模式下仓库详情初始化、目录刷新、分支/标签/README/最新提交加载均不得触发网络请求。
- 为文件行与目录面包屑提供稳定的 Accessibility Identifier。
- fixture 仅在 UI 测试模式与专用启动参数同时启用时生效。


第五阶段 5.9 扩展 Issues 与 Pull Requests UI 自动化覆盖：

- 使用独立启动参数加载本地 Issue/PR fixture，列表、筛选、刷新不得请求真实 GitHub API。
- 验证开放、已关闭、全部三种状态筛选。
- 验证新建 Issue/PR 表单的必填校验与取消流程。
- 为状态选择器、创建入口与列表项提供稳定的 Accessibility Identifier。
- UI 测试模式下拦截创建 Issue/PR 请求，避免误提交真实数据。
- 正常运行时仍走原有 GitHub API 逻辑。


第五阶段 5.10 扩展提交历史 UI 自动化覆盖：

- 使用 `-ui-testing-commit-fixtures` 注入本地提交记录，不访问真实 GitHub API。
- 验证仓库头部的提交历史入口、提交列表标题和提交信息展示。
- UI 测试模式下提交列表、刷新和分页均使用本地数据或安全空状态。
- 为提交历史入口和提交行提供稳定的 Accessibility Identifier。

## CI Queue Manager 1.0

统一入口：`.github/workflows/ci-orchestrator.yml`

### 阶段二 Orchestrator

执行依赖关系：

1. SwiftLint 与 Bootstrap 两个独立 Job 并行执行。
2. Bootstrap 生成并验证 Xcode 工程，将工程作为本次 run 的短期 Artifact 传递给测试 Job。
3. SwiftLint 与 Bootstrap 均成功后启动 XCTest。
4. XCTest 成功后启动 XCUITest。
5. 最终 Summary 汇总事件、ref、commit SHA、SwiftLint、Bootstrap 和测试结果；任何必要阶段失败都会使 Orchestrator 失败。

### 队列隔离与取消策略

- main Push 按 Git ref 分组。
- PR 按 PR number 分组，不同 PR 不互相影响。
- 手动运行按 run ID 独立分组。
- Orchestrator 使用 `cancel-in-progress: false`：运行中的旧任务允许完成；同组较旧的待处理任务由新待处理任务替换。
- 本阶段不执行运行中任务的主动取消；SHA 去重、过期判断和 GitHub API 取消属于后续 Latest 队列阶段。
- 生产构建使用独立的 `production-build` concurrency group，`cancel-in-progress: false`，与普通 CI 完全隔离。

### 可复用工作流

| 文件 | 职责 |
| --- | --- |
| `.github/workflows/ci-swiftlint.yml` | SwiftLint 质量门禁 |
| `.github/workflows/ci-bootstrap.yml` | 工具链、XcodeGen 与 Scheme 验证 |
| `.github/workflows/ci-unit-tests.yml` | XCTest → XCUITest 串行执行 |
| `.github/actions/ci-bootstrap/action.yml` | 统一工具链安装与项目生成 |

子工作流只使用 `workflow_call`，不重复监听 Push、PR 或手动事件，不定义与 Orchestrator 冲突的 concurrency。


### 阶段三：Latest 队列治理（实施中）

- 队列键按 main 分支、PR 编号和手动 run ID 隔离；同组运行中任务保留，待处理任务由 GitHub Actions concurrency 替换。
- 新增 `scripts/ci/queue-controller.sh`：Push/PR 启动前解析远端分支最新 SHA；发现当前 SHA 已过期时输出跳过决策，防止旧提交继续消耗 XCTest/XCUITest Runner。
- 手动触发保持独立，不参与自动 SHA 过滤。
- 后续需完成 Orchestrator 对 Queue Controller 输出的门禁接入、成功 SHA 去重和队列场景实测。
