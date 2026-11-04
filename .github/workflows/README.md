# GitHub Actions 工作流目录

本目录存放项目 CI/CD 工作流配置。

## CI Queue Manager 1.0

### 唯一自动入口：ci-orchestrator.yml

监听 Push（main）、Pull Request 和 workflow_dispatch。所有事件由 Orchestrator 编排：

1. Latest queue guard 检查当前提交是否仍是对应队列的最新 ref。
2. 已通过的相同队列/ref/SHA 命中缓存时，跳过重复 CI。
3. SwiftLint 与 Bootstrap 并行执行。
4. 两个质量门禁都成功后，才启动 XCTest。
5. XCTest 成功后才启动 XCUITest。
6. 汇总队列决策、提交 SHA 与每阶段结果；队列检查失败或必要阶段失败时整体失败。

Bootstrap 生成并验证 Xcode 工程后，将工程作为本次 run 的短期 Artifact 交给测试 Job，避免在不同 Runner 上重复安装工具和生成工程。

### 队列隔离与 Latest 策略

- Push：按完整 Git ref 分组。
- workflow_dispatch：按所选 Git ref 分组，与同一 ref 的 Push 共享队列。
- Pull Request：按 PR number 分组，不同 PR 互不影响；过期检查比较 GitHub 当前 PR merge ref，而不是 head branch SHA。
- cancel-in-progress=true：同组新运行到来时取消正在执行的旧运行；GitHub Actions 原生并发只保留一个待处理运行，新的待处理运行会替换旧待处理运行。
- Queue guard 在昂贵的 SwiftLint、Bootstrap 和模拟器测试之前再次核对远端 ref；已过期的运行直接跳过。
- 成功的队列/ref/SHA 使用 Actions Cache 记录；相同提交再次触发时跳过重复执行。失败或取消的运行不会写入成功缓存。
- Push 与手动运行共享 ref 队列；PR 按 PR number 隔离。生产构建不进入普通 CI concurrency group。

### 可复用工作流与 Action

| 文件 | 职责 |
| --- | --- |
| ci-swiftlint.yml | 可复用 SwiftLint 质量门禁 |
| ci-bootstrap.yml | 可复用工具链与 XcodeGen 检查 |
| ci-unit-tests.yml | 串行执行 XCTest、XCUITest |
| ../actions/ci-bootstrap/action.yml | 安装工具链并生成/验证 Xcode 工程 |

子工作流仅使用 workflow_call，不监听 Push、PR 或手动事件，也不声明共享 concurrency group。手动 CI 从 ci-orchestrator.yml 的 Run workflow 入口启动。

### 队列验收

运行 scripts/test-ci-queue-policy.sh 验证以下场景：

- 最新 Push 被接受，过期 Push 被跳过。
- PR 使用 refs/pull/<number>/merge 校验，避免将 PR head SHA 与 merge SHA 错误比较。
- 最新 PR merge ref 被接受，过期 PR merge ref 被跳过。
- workflow_dispatch 与相同 ref 的 Push 共享队列。
- 无法解析远端 ref 时 fail closed，不允许未经验证的提交进入测试阶段。
- 已成功 SHA 命中缓存时跳过重复测试；失败/取消运行不缓存。

## 生产构建

### production-build.yml

生产构建当前触发条件为：
- 推送到 testping 分支。
- workflow_dispatch 手动触发。

生产构建使用独立的 production-build concurrency group，设置 cancel-in-progress=false。运行中的生产构建不会被普通 CI 或后续生产触发中断；生产构建不加入普通 CI 队列。触发分支、发布步骤与制品行为保持不变。

## 维护约定

1. 自动 CI 事件入口只保留在 ci-orchestrator.yml。
2. Queue guard 必须在 SwiftLint、Bootstrap 和测试之前执行。
3. SwiftLint 和 Bootstrap 必须都成功后才可执行测试。
4. XCTest 与 XCUITest 串行执行，XCUITest 依赖 XCTest 成功。
5. 所有测试 Artifacts 使用 run ID 与 attempt 唯一命名。
6. 普通 CI 与生产构建队列隔离。
7. 成功 SHA 缓存只在全部必要 CI 阶段成功后写入。
8. 敏感信息使用 GitHub Secrets，不在工作流中硬编码。
