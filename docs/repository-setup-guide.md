# 仓库环境配置手册

## 文档信息

| 项目 | 内容 |
|------|------|
| 文档名称 | 仓库环境配置手册 |
| 适用项目 | GitHub iOS 客户端 |
| 文档版本 | v1.0.0 |
| 最后更新 | 2026-09-09 |

---

## 一、仓库目录结构规范

```
GitHub/
├── .github/
│   └── workflows/                    # CI/CD 工作流目录（GitHub标准目录）
│       ├── production-build.yml      # 生产构建流水线（仅main分支触发）
│       └── pr-quality-gate.yml       # PR代码校验流水线（PR/非main分支触发）
├── scripts/                          # CI/CD 脚本目录（纳入版本管控）
│   ├── bump-version.sh               # 版本计算脚本（三段式语义版本自动进位）
│   ├── test-bump-version.sh          # 版本进位单元测试脚本（87个测试用例）
│   ├── update-changelog.sh           # README更新日志脚本
│   └── generate-artifact-metadata.sh # 制品元数据生成脚本
├── docs/                             # 项目文档目录
│   ├── repository-setup-guide.md     # 仓库环境配置手册（本文档）
│   ├── pipeline-operations-guide.md  # 流水线运维&故障排查文档
│   └── artifact-guide.md             # 制品说明文档
├── GitHub/                           # iOS 项目源码目录
│   ├── Core/                         # 核心层（Keychain、网络API、状态管理）
│   ├── Models/                       # 数据模型层
│   ├── Views/                        # 视图层（SwiftUI）
│   ├── Assets.xcassets/              # 资源文件
│   ├── Info.plist                    # 应用配置（版本号存储位置）
│   └── GitHubApp.swift               # 应用入口
├── GitHub.xcodeproj/                 # Xcode 项目文件
├── .gitignore                        # Git 忽略规则
└── README.md                         # 项目说明文档（含更新日志）
```

---

## 二、分支策略规范

### 2.1 分支定义

| 分支 | 用途 | 触发流水线 | 保护级别 |
|------|------|-----------|----------|
| `main` | 生产分支，存放可发布代码 | 生产构建流水线 | 🔒 受保护，禁止直接推送 |
| `feature/*` | 功能开发分支 | PR代码校验流水线 | 普通 |
| `bugfix/*` | Bug修复分支 | PR代码校验流水线 | 普通 |
| `hotfix/*` | 紧急修复分支 | PR代码校验流水线 | 普通 |
| `release/*` | 发布准备分支 | PR代码校验流水线 | 普通 |

### 2.2 分支触发强隔离机制

**核心规则：仅 main 分支正式推送触发完整生产流水线**

- ✅ **main 分支推送**：触发 `production-build.yml`（完整生产构建）
- ✅ **Pull Request**：触发 `pr-quality-gate.yml`（仅编译校验+静态分析+警告门禁）
- ✅ **非 main 分支推送**：触发 `pr-quality-gate.yml`（仅编译校验）
- ❌ **PR/其他分支严格禁止**：版本递增、README修改、IPA导出、仓库提交变更

### 2.3 合并流程

1. 从 `main` 分支创建功能分支 `feature/xxx`
2. 开发完成后提交 PR 到 `main`
3. PR 自动触发代码校验流水线
4. 校验通过 + 代码评审通过后合并到 `main`
5. 合并到 `main` 自动触发生产构建流水线
6. 生产流水线自动完成版本递增、编译、IPA导出、日志更新

---

## 三、GitHub Actions 环境配置

### 3.1 Runner 环境

| 配置项 | 值 | 说明 |
|--------|-----|------|
| 操作系统 | `macos-14` | macOS 14 Sonoma，支持 Xcode 15 |
| Xcode 版本 | 15.4 | 手动指定，避免Runner默认版本变更导致构建失败 |
| iOS SDK | iphoneos | 真机SDK，生成可安装的IPA |
| 部署目标 | iOS 15.0 | 最低支持iOS 15 |

### 3.2 无需配置的 Secrets

**重要：本项目 CI 流水线不需要任何签名相关 Secrets**

| Secrets | 是否需要 | 说明 |
|---------|---------|------|
| 代码签名证书 | ❌ 不需要 | 流水线不执行任何代码签名 |
| Provisioning Profile | ❌ 不需要 | 流水线不读取描述文件 |
| Apple ID | ❌ 不需要 | 不涉及App Store上传 |
| 自定义Token | ❌ 不需要 | 使用GitHub自带的 `GITHUB_TOKEN` |

**设计原则**：签名操作完全交给全能签本地处理，CI只导出干净未签名IPA，彻底消除证书泄露风险。

### 3.3 内置环境变量

生产流水线使用以下全局环境变量（在 workflow 文件顶部定义）：

```yaml
env:
  PROJECT_NAME: GitHub              # 项目名称
  SCHEME_NAME: GitHub               # Xcode Scheme名称
  XCODE_PROJECT: GitHub.xcodeproj  # Xcode项目文件
  INFO_PLIST_PATH: GitHub/Info.plist # Info.plist路径
  IPA_FILE_NAME: GitHub.ipa         # IPA文件名
  ARTIFACT_RETENTION_DAYS: 30       # Artifacts保留天数
  DEPLOYMENT_TARGET: 15.0           # iOS部署目标
```

PR校验流水线额外定义：

```yaml
env:
  WARNING_THRESHOLD: 10  # 编译警告阈值，超过则PR失败
```

---

## 四、版本号管理规范

### 4.1 版本号格式

采用 **三段式纯数字语义化版本**：`主版本.次版本.补丁号`

| 段位 | 取值范围 | 说明 |
|------|---------|------|
| 主版本 | 0~999 | 重大架构变更、不兼容更新 |
| 次版本 | 0~9 | 新功能添加、向后兼容更新 |
| 补丁号 | 0~9 | Bug修复、小优化 |

### 4.2 自动进位规则

```
补丁号 < 9  →  补丁号 +1
补丁号 == 9 →  补丁置0，次版本 +1
次版本 == 9 且 补丁号 == 9  →  补丁置0、次版本置0、主版本 +1
```

**示例**：
- `1.0.0` → `1.0.1`
- `1.0.9` → `1.1.0`
- `1.9.9` → `2.0.0`
- `2.3.9` → `2.4.0`

### 4.3 版本号存储位置

版本号存储在 `GitHub/Info.plist` 文件中：

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>  <!-- 显示版本号，自动递增 -->
<key>CFBundleVersion</key>
<string>1725849600</string>  <!-- 构建号，时间戳，每次构建自动更新 -->
```

### 4.4 版本递增触发时机

**仅在 main 分支推送时自动递增**，每次生产构建递增一次补丁号。

- ✅ main 分支合并 PR → 自动递增
- ✅ main 分支手动触发 workflow_dispatch → 自动递增
- ❌ PR 提交/更新 → 不递增（仅校验）
- ❌ 功能分支推送 → 不递增（仅校验）

---

## 五、Artifacts 管理规范

### 5.1 产物类型

| 产物名称 | 内容 | 保留天数 | 说明 |
|---------|------|---------|------|
| `GitHub-iOS-IPA-v{版本号}` | 未签名IPA文件 | 30天 | 主制品，供全能签导入 |
| `GitHub-iOS-Metadata-v{版本号}` | 制品元数据JSON | 30天 | 包含SHA256、版本、Commit等 |
| `GitHub-iOS-BuildLog-v{版本号}` | 编译日志 | 7天 | 便于问题排查 |

### 5.2 产物绝对隔离规范

**核心规则：编译产物 IPA 终身严禁提交到 Git 仓库**

- ✅ IPA 仅作为 GitHub Actions Artifacts 临时存储
- ✅ 用户手动下载 Artifacts 中的 IPA
- ❌ 禁止将 IPA commit/push 到任何分支
- ❌ 禁止将 IPA 放入 Release Assets（如需发布，手动上传）

### 5.3 自动清理机制

生产流水线最后一个 Job 自动清理超过 30 天的 Artifacts，节约 GitHub 存储配额。

---

## 六、本地开发环境配置

### 6.1 必需工具

| 工具 | 最低版本 | 用途 |
|------|---------|------|
| macOS | 13.0+ | 编译iOS应用 |
| Xcode | 15.0+ | IDE和编译工具 |
| Git | 2.30+ | 版本控制 |
| ShellCheck | 0.7.0+ | Shell脚本语法检查（可选） |

### 6.2 本地编译命令

```bash
# 进入项目目录
cd GitHub

# 编译（未签名模式）
xcodebuild \
  -project GitHub.xcodeproj \
  -scheme GitHub \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 6.3 本地运行版本单元测试

```bash
# 运行版本进位单元测试（87个测试用例）
bash scripts/test-bump-version.sh
```

### 6.4 本地手动版本递增（测试用）

```bash
# 手动执行版本递增（会修改Info.plist）
bash scripts/bump-version.sh
```

**注意**：本地手动递增仅用于测试，正式版本递增由CI流水线自动完成。

---

## 七、安全规范

### 7.1 Token 安全

- 用户的 GitHub Personal Access Token 仅存储在 iOS 设备本地 Keychain
- CI 流水线不接触、不存储用户 Token
- 仓库中禁止硬编码任何 Token、密钥、证书

### 7.2 制品安全

- 每个 IPA 自动计算 SHA256 哈希，用于完整性校验
- 制品元数据 JSON 随 IPA 一起归档，可离线审计
- 用户下载后可通过 SHA256 校验 IPA 是否被篡改

### 7.3 代码安全

- PR 必须通过编译校验和静态分析才能合并
- 编译警告超过阈值自动拦截 PR
- 所有 CI 脚本纳入版本管控，变更可追溯

---

## 八、常见问题

### Q1: 为什么 CI 不做代码签名？

A: 签名操作涉及证书和私钥，放在 CI 中有泄露风险。本项目采用「CI 导出未签名 IPA + 全能签本地重签名」的架构，既保证了 CI 的安全性，又简化了证书管理。

### Q2: 版本号可以手动修改吗？

A: 不建议。版本号由 CI 流水线自动递增，确保版本序列连续、不重复、不跳号。如需调整主版本或次版本，应通过修改脚本逻辑并经过 PR 评审。

### Q3: 如何下载构建好的 IPA？

A: 进入仓库的 Actions 页面，选择最新的成功构建，在页面底部 Artifacts 区域下载 `GitHub-iOS-IPA-v{版本号}`。

### Q4: IPA 可以直接安装吗？

A: 不能直接安装。CI 导出的是未签名 IPA，需要使用全能签等工具进行本地重签名后才能安装到 iOS 设备。详见《制品说明文档》。
