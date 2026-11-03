# CI 基础设施

## 阶段一：工具链与项目生成检查

当前 CI 基础环境：

| 项目 | 版本 |
| --- | --- |
| GitHub Actions Runner | macOS 14 |
| Xcode | 15.4 |
| Swift | 5.10（随 Xcode 15.4 提供） |
| XcodeGen | 2.46.0（当前 CI Runner 安装版本） |
| SwiftLint | 0.65.1（当前 CI Runner 安装版本） |
| iOS Deployment Target | 16.0 |

工作流：`.github/workflows/ci-bootstrap.yml`

本地执行：

```bash
brew install xcodegen swiftlint
chmod +x scripts/ci-bootstrap.sh
GITHUB_SHA="$(git rev-parse HEAD)" ./scripts/ci-bootstrap.sh
```

检查脚本会：

1. 输出 macOS、Xcode、Swift、XcodeGen 和 SwiftLint 版本。
2. 检查项目配置、SwiftLint 配置和 Info.plist 是否存在。
3. 使用 XcodeGen 生成 `GitHub.xcodeproj`。
4. 将生成工程的 `objectVersion` 规范为 60，以兼容 Xcode 15.4。
5. 使用 `xcodebuild -list` 验证工程和 GitHub Scheme。
6. 确认当前检出的提交 SHA 与 CI 触发 SHA 一致。

> 当前阶段只验证 CI 工具链和 XcodeGen 工程生成，不执行 SwiftLint 全量检查、XCTest 或 XCUITest。这些检查分别在后续阶段接入。
