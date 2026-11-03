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

工作流：`.github/workflows/ci-unit-tests.yml`

执行顺序：

1. 检出触发提交并校验工具链版本。
2. 执行 SwiftLint 质量门禁。
3. 使用 XcodeGen 生成工程并验证 Scheme。
4. 检查 iPhone 15 模拟器可用性。
5. 顺序执行 XCTest 与 XCUITest。
6. 无论测试成功或失败，上传 `TestResults.xcresult`（若已生成）。

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


## CI Queue Manager 1.0

统一入口：`.github/workflows/ci-orchestrator.yml`

执行顺序：

1. SwiftLint 质量门禁。
2. Bootstrap Composite Action：选择 Xcode 15.4、安装 XcodeGen/SwiftLint、生成并验证 Xcode 工程。
3. 检查 iPhone 15 Simulator。
4. 顺序执行 XCTest 与 XCUITest。
5. 上传带 run ID/attempt 的测试结果制品。
6. 汇总 SwiftLint 与测试 Job 状态；Lint 未通过时测试不会启动。

### 并发与取消策略

- Push 队列按 Git ref 隔离；新提交取消同分支旧运行。
- PR 队列按 PR number 隔离；新提交取消同 PR 旧运行。
- 手动运行按 run ID 独立，不被 Push/PR 取消。
- 生产构建继续使用自身触发与并行策略，不进入普通 CI 队列。
- 仅 Orchestrator 声明 concurrency，避免 reusable workflow 同名组取消父工作流。
- 同组最多一个运行任务和一个待运行任务；新待运行任务替换旧待运行任务。
