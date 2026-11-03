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

UI 测试启动应用时必须设置 `-ui-testing` 与 `UI_TESTING=1`。按需使用专用启动参数加载内存 fixture。测试模式不得读取或写入真实账号凭据、Keychain、UserDefaults，不得访问真实 GitHub API；每个用例结束时终止应用。CI 禁用测试并行执行。

## 本地执行

```bash
brew install xcodegen swiftlint
./scripts/ci-swiftlint.sh
./scripts/ci-bootstrap.sh
xcodebuild test -project GitHub.xcodeproj -scheme GitHub \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:GitHubTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild test -project GitHub.xcodeproj -scheme GitHub \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:GitHubUITests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

## UI 自动化覆盖

- 5.1：测试基础设施、Target/Scheme、测试启动约定与持久化隔离。
- 5.2：登录页控件、Token 校验、拦截真实登录及重启状态。
- 5.3：主界面 Tab 导航与隔离登录壳层。
- 5.4：仓库列表搜索、可见性筛选与组合条件。
- 5.5：星标仓库列表筛选、描述搜索和空状态。
- 5.6：个人资料字段、关于页导航和退出确认。
- 5.7：内存账号展示、切换、添加取消和删除。
- 5.8：仓库文件浏览、本地目录树、多级导航和面包屑。
- 5.9：Issues/PR 列表筛选、创建表单校验和取消。
- 5.10：提交历史入口、本地提交列表与安全刷新。

## CI Queue Manager 1.0

统一入口：`.github/workflows/ci-orchestrator.yml`

### 阶段二 Orchestrator

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
- 生产构建不加入普通 CI concurrency group，保持独立。

### 可复用工作流

| 文件 | 职责 |
| --- | --- |
| `.github/workflows/ci-swiftlint.yml` | SwiftLint 质量门禁 |
| `.github/workflows/ci-bootstrap.yml` | 工具链、XcodeGen 与 Scheme 验证 |
| `.github/workflows/ci-unit-tests.yml` | XCTest → XCUITest 串行执行 |
| `.github/actions/ci-bootstrap/action.yml` | 统一工具链安装与项目生成 |

子工作流只使用 `workflow_call`，不重复监听 Push、PR 或手动事件，不定义与 Orchestrator 冲突的 concurrency。
