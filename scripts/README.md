# CI 脚本目录

本目录存放 CI/CD 流水线使用的 Shell 脚本，所有脚本均纳入 Git 版本管控，遵循工业级编码规范。

## 文件说明

### bump-version.sh
**版本计算脚本** - 独立封装三段式版本解析与进位计算逻辑

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `PLIST_PATH` | Info.plist 文件路径 | 版本号读取和写入的目标文件 |
| `CFBundleShortVersionString` | 版本号键名 | Info.plist 中存储版本号的键 |
| `MAJOR` | 主版本号 | 三段式版本的第一段，重大变更时递增 |
| `MINOR` | 次版本号 | 三段式版本的第二段，功能新增时递增 |
| `PATCH` | 补丁号 | 三段式版本的第三段，Bug 修复时递增，范围 0~9 |
| `NEW_VERSION` | 计算后的新版本号 | 进位计算后的完整版本号 |
| `set -euo pipefail` | 严格模式 | 脚本错误立即退出，未定义变量报错，管道错误捕获 |

**版本进位规则：**
- 补丁号 < 9：补丁号 +1
- 补丁号 == 9：补丁置 0，次版本 +1
- 次版本 == 9 且补丁 == 9：补丁置 0、次版本置 0，主版本 +1
- 示例：1.0.9 → 1.1.0；1.9.9 → 2.0.0；2.3.9 → 2.4.0

**使用方法：**
```bash
./scripts/bump-version.sh
```

---

### test-bump-version.sh
**版本进位单元测试脚本** - 自动校验多组边界案例

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `TEST_COUNT` | 测试用例总数 | 共 87 个测试用例 |
| `PASSED` | 通过用例数 | 测试通过的用例计数 |
| `FAILED` | 失败用例数 | 测试失败的用例计数 |
| `test_version_bump` | 版本进位测试函数 | 输入旧版本，验证计算出的新版本是否正确 |
| `test_invalid_version` | 非法版本测试函数 | 验证非三段式、非数字版本号是否被正确拒绝 |
| `test_plist_write` | Plist 写入测试函数 | 验证版本号能否正确写入 Info.plist |

**测试覆盖场景：**
- 正常递增（补丁 0~8）
- 补丁进位（补丁 9 → 次版本 +1）
- 次版本进位（次版本 9 且补丁 9 → 主版本 +1）
- 多级进位（1.9.9 → 2.0.0）
- 非法格式拒绝（非三段式、非数字、空值）
- Plist 读写一致性

**使用方法：**
```bash
./scripts/test-bump-version.sh
```

---

### update-changelog.sh
**README 更新日志脚本** - 在 README.md 顶部追加结构化更新日志

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `README_PATH` | README.md 文件路径 | 更新日志写入的目标文件 |
| `VERSION` | 当前版本号 | 本次构建的版本号 |
| `GIT_COMMIT` | Git 提交短哈希 | 触发本次构建的 commit 短哈希 |
| `BUILD_TIME` | 构建时间 | 构建完成的时间戳（北京时间 UTC+8） |
| `IPA_SHA256` | IPA 文件 SHA256 | 编译产物的 SHA256 哈希值，用于完整性校验 |
| `CHANGELOG_MARKER` | 日志标记位 | README.md 中标识更新日志区域的注释标记 |
| `LOG_ENTRY` | 日志条目 | 格式化后的单条更新日志文本 |

**日志格式：**
```
## vX.Y.Z
- 构建提交: abc1234
- 构建时间: 2026-09-10 17:00:00
- IPA SHA256: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
- 更新内容: [功能描述]
```

**使用方法：**
```bash
./scripts/update-changelog.sh
```

---

### generate-artifact-metadata.sh
**制品元数据生成脚本** - 生成独立制品元数据 JSON 文件

**功能参数说明：**

| 参数/变量 | 中文释义 | 说明 |
|-----------|---------|------|
| `OUTPUT_FILE` | 输出文件路径 | artifact-metadata.json 的生成路径 |
| `VERSION` | 版本号 | 本次构建的版本号 |
| `GIT_COMMIT` | Git 短哈希 | 触发本次构建的 commit 短哈希 |
| `BUILD_TIME` | 构建时间 | 构建完成的时间戳 |
| `BUILD_DURATION` | 构建耗时 | 从构建开始到完成的总耗时（秒） |
| `IPA_FILE_NAME` | IPA 文件名 | 编译产物的文件名 |
| `IPA_FILE_SIZE` | IPA 文件大小 | 编译产物的文件大小（字节） |
| `IPA_SHA256` | IPA SHA256 | 编译产物的 SHA256 哈希值 |
| `METADATA_JSON` | 元数据 JSON | 格式化后的完整元数据 JSON 字符串 |

**输出 JSON 结构：**
```json
{
  "version": "x.y.z",
  "git_commit": "abc1234",
  "build_time": "2026-09-10T17:00:00+08:00",
  "build_duration_seconds": 120,
  "ipa_file_name": "GitHub.ipa",
  "ipa_file_size_bytes": 2569011,
  "ipa_sha256": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

**使用方法：**
```bash
./scripts/generate-artifact-metadata.sh
```

---

## 脚本编码规范

1. 所有脚本启用 `set -euo pipefail` 严格模式
2. 全中文精细化注释，说明底层逻辑、步骤作用、参数含义、风险点
3. 变量抽离，消除硬编码，便于后期调整
4. 每一步设置明确退出码，错误信息可读性强
5. 前置状态校验、参数合法性预判，异常全拦截
6. 支持本地单独调试，可直接作为企业工程模板复用
