# GitHub Actions 工作流目录

本目录存放项目的 CI/CD 工作流配置文件，所有工作流配置均纳入 Git 版本管控。

## 文件说明

### production-build.yml
**生产构建流水线**，仅在 `main` 分支推送时触发。

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `version-bump` | 版本计算与单元测试 | 读取 Info.plist 版本号，执行三段式语义版本递增，运行 87 个单元测试用例 |
| `build-ipa` | Xcode编译与IPA导出 | 使用 XcodeGen 生成项目，编译导出未签名 IPA，计算 SHA256 哈希，生成制品元数据 |
| `update-changelog` | 更新README更新日志 | 在 README.md 顶部插入新版日志（版本号、commit哈希、构建时间、SHA256） |
| `cleanup-artifacts` | 清理过期Artifacts | 自动清理超过 7 天的旧版本 Actions Artifacts |

**触发条件：**
- 仅 `main` 分支推送触发
- PR 和其他分支不触发此流水线

**制品输出：**
- GitHub.ipa（未签名，供全能签重签名）
- artifact-metadata.json（制品元数据）

---

### pr-quality-gate.yml
**PR 质量门禁流水线**，在所有分支的 Pull Request 时触发。

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `build-check` | 编译校验 | 执行 Xcode 语法编译校验，确保代码可编译 |
| `static-analysis` | 静态代码分析 | 执行静态代码分析，检查代码质量问题 |
| `warning-threshold` | 编译警告阈值 | 编译警告数量超出阈值时标记 PR 失败 |

**严格禁止：**
- 版本递增
- README 修改
- IPA 导出
- 仓库提交变更

**触发条件：**
- 所有分支的 Pull Request
- 其他分支推送（仅执行编译校验）

---

## 目录规范

1. 所有工作流文件必须存放于此目录
2. 工作流配置变更需经过 PR 审核
3. 禁止在工作流中硬编码敏感信息，使用 GitHub Secrets
4. 流水线全程不执行任何代码签名操作
