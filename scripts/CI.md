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
- 验证主界面“仓库”和“我的”Tab 均存在，并可切换到“我的”导航页面。
- 该启动参数只在 UI 测试模式下生效，不改变正常启动和生产登录行为。
