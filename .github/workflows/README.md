# GitHub Actions 工作流目录

本目录存放项目的 CI/CD 工作流配置文件。

## CI 统一入口

### ci-orchestrator.yml

CI Queue Manager 1.0 统一入口，负责 Push、Pull Request 和手动 CI 调度。

执行顺序：
1. SwiftLint 质量门禁。
2. Bootstrap：安装工具链、生成并验证 Xcode 工程。
3. XCTest + XCUITest：在 iPhone 15 Simulator 上顺序执行。
4. 汇总各阶段结果；任一必要阶段失败，统一入口失败。

队列策略：
- 同一 Push 分支的新提交取消该分支正在运行的旧自动 CI。
- 同一 PR 的新提交取消该 PR 正在运行的旧自动 CI。
- Push、PR、手动运行使用不同 concurrency group，互不误取消。
- 手动运行使用唯一 run ID，始终独立执行。
- 仅 Orchestrator 定义 concurrency，Reusable Workflows 不声明共享组。

### 可复用工作流与 Action

| 文件 | 职责 |
| --- | --- |
| ci-swiftlint.yml | 可复用 SwiftLint 质量门禁 |
| ci-unit-tests.yml | 可复用 Bootstrap + XCTest + XCUITest |
| ci-bootstrap.yml | 可复用独立基础设施检查 |
| ../actions/ci-bootstrap/action.yml | 统一工具链安装与 XcodeGen 校验模块 |

子工作流仅通过 workflow_call 调用，不再监听 Push、PR 或手动事件，避免重复触发。手动 CI 请从 ci-orchestrator.yml 的 Run workflow 入口启动。

## 生产构建

### production-build.yml

生产构建当前实际触发条件：
- 推送到 testping 分支。
- workflow_dispatch 手动触发。
- PR 不触发。

生产构建保持独立于普通 CI：本阶段不修改其触发分支、发布行为或原有并行策略，不加入普通 CI concurrency group。

主要功能包括版本检查、Xcode 编译、未签名 IPA 导出、SHA256 元数据、README 更新日志、Artifacts 上传与清理。

## 维护约定

1. 自动 CI 事件入口只保留在 ci-orchestrator.yml。
2. 可复用工作流只使用 workflow_call。
3. 不在 Reusable Workflow 中声明与 Orchestrator 冲突的 concurrency group。
4. 所有 Artifacts 使用 run ID 与 attempt 唯一命名，避免并发覆盖。
5. 生产构建与普通 CI 队列隔离。
6. 敏感信息使用 GitHub Secrets，不在工作流中硬编码。
