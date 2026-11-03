# GitHub Actions 工作流目录

本目录存放项目 CI/CD 工作流配置。

## CI Queue Manager 1.0

### 唯一自动入口：ci-orchestrator.yml

监听 Push（main）、Pull Request 和 workflow_dispatch。所有事件由 Orchestrator 编排：

1. SwiftLint 与 Bootstrap 并行执行。
2. 两个质量门禁都成功后，才启动 XCTest。
3. XCTest 成功后才启动 XCUITest。
4. 汇总提交 SHA、事件、引用分支和每阶段结果；任一必要阶段失败则整体失败。

Bootstrap 生成并验证 Xcode 工程后，将工程作为本次 run 的短期 Artifact 交给测试 Job，避免在不同 Runner 上重复安装工具和生成工程。

### 队列隔离与运行策略

- main Push：按 Git ref 分组。
- Pull Request：按 PR number 分组，不同 PR 互不影响。
- workflow_dispatch：每次 run ID 独立分组，不被 Push/PR 任务替换。
- `cancel-in-progress: false`：新提交不会中断同组正在运行的旧任务；GitHub Actions 原生并发只保留一个待处理任务，新的待处理运行会替换旧待处理运行。
- 本阶段不主动取消运行中的旧 SHA；精确 SHA 过期识别与 API 取消属于后续 Latest 队列阶段。
- 生产构建不复用普通 CI concurrency group。

### 可复用工作流与 Action

| 文件 | 职责 |
| --- | --- |
| ci-swiftlint.yml | 可复用 SwiftLint 质量门禁 |
| ci-bootstrap.yml | 可复用工具链与 XcodeGen 检查 |
| ci-unit-tests.yml | 串行执行 XCTest、XCUITest |
| ../actions/ci-bootstrap/action.yml | 安装工具链并生成/验证 Xcode 工程 |

子工作流仅使用 workflow_call，不监听 Push、PR 或手动事件，也不声明共享 concurrency group。手动 CI 从 ci-orchestrator.yml 的 Run workflow 入口启动。

## 生产构建

### production-build.yml

生产构建当前触发条件为：
- 推送到 testping 分支。
- workflow_dispatch 手动触发。

生产构建使用独立的 `production-build` concurrency group，设置 `cancel-in-progress: false`。运行中的生产构建不会被普通 CI 或后续生产触发中断；生产构建不加入普通 CI 队列。触发分支、发布步骤与制品行为保持不变。

## 维护约定

1. 自动 CI 事件入口只保留在 ci-orchestrator.yml。
2. SwiftLint 和 Bootstrap 必须都成功后才可执行测试。
3. XCTest 与 XCUITest 串行执行，XCUITest 依赖 XCTest 成功。
4. 所有测试 Artifacts 使用 run ID 与 attempt 唯一命名。
5. 普通 CI 与生产构建队列隔离。
6. 敏感信息使用 GitHub Secrets，不在工作流中硬编码。
