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

XcodeGen 通过 project.yml 声明三个 Target：
- GitHub：iOS 主应用。
- GitHubTests：单元测试。
- GitHubUITests：iOS Simulator UI 自动化测试。

GitHub Scheme 同时包含 XCTest 与 XCUITest，并启用代码覆盖率收集。

## UI 测试隔离约定

UI 测试启动应用时必须同时设置：
- 启动参数：-ui-testing
- 启动环境变量：UI_TESTING=1

UI 测试模式不读取真实 Keychain 凭据，不调用真实 GitHub API，不持久化测试账号状态，并跳过启动副作用。每个 UI 测试结束时终止被测应用。CI 禁用 Xcode 测试并行执行，避免模拟器和共享状态竞争。

## 本地执行

    brew install xcodegen swiftlint
    ./scripts/ci-swiftlint.sh
    ./scripts/ci-bootstrap.sh
    xcodebuild test -project GitHub.xcodeproj -scheme GitHub -destination 'platform=iOS Simulator,name=iPhone 15' -resultBundlePath TestResults.xcresult -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO

## GitHub Actions：CI Queue Manager 1.0

统一入口：.github/workflows/ci-orchestrator.yml

执行顺序：
1. ci-swiftlint.yml：SwiftLint 质量门禁。
2. ci-unit-tests.yml：调用统一 Bootstrap Action，安装工具链、生成并验证 Xcode 工程。
3. 检查 iPhone 15 模拟器。
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

## UI 自动化覆盖范围

UI 测试继续使用 -ui-testing 与 UI_TESTING=1，不得使用真实凭据或访问真实 GitHub 服务。当前覆盖登录、主界面导航、仓库列表搜索筛选、星标仓库、个人资料及多账号管理流程。Fixture 只在明确的 UI 测试启动参数下启用，不改变正常运行行为。
