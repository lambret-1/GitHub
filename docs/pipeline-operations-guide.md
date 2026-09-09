# 流水线运维 & 故障排查文档

## 文档信息

| 项目 | 内容 |
|------|------|
| 文档名称 | 流水线运维 & 故障排查文档 |
| 适用项目 | GitHub iOS 客户端 |
| 文档版本 | v1.0.0 |
| 最后更新 | 2026-09-09 |

---

## 一、流水线架构总览

### 1.1 双流水线隔离架构

```
┌─────────────────────────────────────────────────────────────┐
│                        GitHub 仓库                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    PR/非main分支    ┌──────────────────┐ │
│  │  代码提交     │ ──────────────────→ │ PR代码校验流水线  │ │
│  │  (功能分支)   │                      │ (pr-quality-gate)│ │
│  └──────────────┘                      └──────────────────┘ │
│         │                                    │                │
│         │ 合并PR到main                       │ 仅校验         │
│         ▼                                    ▼                │
│  ┌──────────────┐    main分支推送    ┌──────────────────┐ │
│  │  main 分支    │ ──────────────────→ │  生产构建流水线   │ │
│  │  (受保护)     │                      │ (production-build)│ │
│  └──────────────┘                      └──────────────────┘ │
│                                              │                │
│                                              ▼                │
│                                    ┌──────────────────┐      │
│                                    │  完整生产构建     │      │
│                                    │  1.版本单元测试   │      │
│                                    │  2.版本自动递增   │      │
│                                    │  3.Xcode编译      │      │
│                                    │  4.导出未签名IPA  │      │
│                                    │  5.SHA256校验     │      │
│                                    │  6.更新README日志 │      │
│                                    │  7.提交版本变更   │      │
│                                    │  8.上传Artifacts  │      │
│                                    │  9.清理旧制品     │      │
│                                    └──────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 生产流水线 Job 依赖关系

```
version-bump (版本计算与单元测试)
       │
       ▼
build-ipa (Xcode编译与IPA导出)
       │
       ├──────────────┐
       ▼              ▼
update-changelog  cleanup-artifacts
(更新README日志)   (清理过期Artifacts)
```

---

## 二、版本进位逻辑详解

### 2.1 核心算法

```
输入: 当前版本号 (三段式: 主.次.补丁)
输出: 下一个版本号

算法:
  1. 解析版本号为三个整数: major, minor, patch
  2. 如果 patch < 9:
       patch = patch + 1
  3. 否则如果 minor < 9:
       patch = 0
       minor = minor + 1
  4. 否则:
       patch = 0
       minor = 0
       major = major + 1
  5. 组装新版本号: major.minor.patch
```

### 2.2 边界案例验证表

| 输入版本 | 输出版本 | 进位路径 | 说明 |
|---------|---------|---------|------|
| 0.0.0 | 0.0.1 | 补丁+1 | 初始版本 |
| 1.0.8 | 1.0.9 | 补丁+1 | 补丁达上限前 |
| 1.0.9 | 1.1.0 | 补丁置0，次版本+1 | 补丁满9进位 |
| 1.8.9 | 1.9.0 | 补丁置0，次版本+1 | 次版本达上限前 |
| 1.9.9 | 2.0.0 | 补丁置0，次版本置0，主版本+1 | 双重进位 |
| 9.9.9 | 10.0.0 | 主版本+1（可超过9） | 主版本无上限 |
| 99.9.9 | 100.0.0 | 主版本+1 | 主版本大数值 |

### 2.3 单元测试本地运行方法

```bash
# 进入项目根目录
cd GitHub

# 运行版本进位单元测试
bash scripts/test-bump-version.sh

# 预期输出:
#   测试总数:   87
#   通过数:     87
#   失败数:     0
#   通过率:     100%
#   ✅ 全部单元测试通过，版本进位逻辑验证合格！
```

### 2.4 版本脚本本地调试方法

```bash
# 1. 查看当前版本号
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" GitHub/Info.plist

# 2. 执行版本递增（会修改Info.plist）
bash scripts/bump-version.sh

# 3. 查看递增后的版本号
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" GitHub/Info.plist

# 4. 如需回滚，使用Git恢复
git checkout GitHub/Info.plist
```

---

## 三、常见故障排查

### 3.1 版本单元测试失败

**现象**：生产流水线 `version-bump` Job 失败，日志显示单元测试未通过。

**可能原因**：
1. `bump-version.sh` 脚本被修改，进位逻辑出错
2. `test-bump-version.sh` 测试用例被修改
3. 运行环境差异（bash 版本）

**排查步骤**：
```bash
# 1. 本地运行单元测试，复现问题
bash scripts/test-bump-version.sh

# 2. 查看失败的具体测试用例
# 测试输出会列出所有失败用例名称

# 3. 检查最近对脚本的修改
git log --oneline -10 scripts/

# 4. 对比脚本变更
git diff HEAD~1 scripts/bump-version.sh
```

**解决方案**：
- 修复 `bump-version.sh` 中的进位逻辑
- 确保所有 87 个测试用例本地通过后再提交 PR
- 版本脚本修改必须经过 PR 评审，禁止直接推送 main

---

### 3.2 版本号递增失败

**现象**：生产流水线 `version-bump` Job 失败，日志显示版本读取或写入失败。

**可能原因**：
1. `Info.plist` 文件不存在或路径错误
2. `Info.plist` 中 `CFBundleShortVersionString` 键缺失
3. 版本号格式非法（非三段式数字）
4. PlistBuddy 工具不可用（非 macOS 环境）

**排查步骤**：
```bash
# 1. 检查Info.plist是否存在
ls -la GitHub/Info.plist

# 2. 检查版本号键是否存在
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" GitHub/Info.plist

# 3. 检查版本号格式是否合法
# 合法格式: 数字.数字.数字 (如 1.0.0)
# 非法格式: 1.0, v1.0.0, 1.0.0-beta, a.b.c

# 4. 检查运行环境
uname -a  # 应该是 Darwin (macOS)
which /usr/libexec/PlistBuddy  # 应该存在
```

**解决方案**：
- 恢复 `Info.plist` 文件（`git checkout GitHub/Info.plist`）
- 手动修正版本号为合法三段式格式
- 确保流水线运行在 `macos-14` Runner 上

---

### 3.3 Xcode 编译失败

**现象**：生产流水线 `build-ipa` Job 失败，日志显示 xcodebuild 命令返回非0退出码。

**可能原因**：
1. Swift 代码语法错误
2. 缺失依赖库或框架
3. Xcode 项目文件配置错误
4. Info.plist 配置错误
5. Runner 环境 Xcode 版本不兼容

**排查步骤**：
```bash
# 1. 查看编译错误日志（流水线会自动上传 build.log）
#    下载 Artifacts 中的 GitHub-iOS-BuildLog-v{版本号}

# 2. 本地复现编译错误
cd GitHub
xcodebuild \
  -project GitHub.xcodeproj \
  -scheme GitHub \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee build.log

# 3. 查看错误详情
grep -n "error:" build.log

# 4. 查看警告详情
grep -n "warning:" build.log
```

**解决方案**：
- 根据错误日志修复 Swift 代码
- 检查 `project.pbxproj` 配置是否正确
- 确保所有源文件都已添加到 Xcode 项目中
- 本地编译通过后再提交 PR

---

### 3.4 IPA 导出失败

**现象**：生产流水线 `build-ipa` Job 失败，日志显示 IPA 文件不存在或包结构异常。

**可能原因**：
1. 编译成功但 `.app` 产物路径错误
2. `Payload` 目录结构不完整
3. `.app` 内部缺少 `Info.plist`
4. zip 打包命令失败

**排查步骤**：
```bash
# 1. 检查编译产物路径
ls -la build/Build/Products/Release-iphoneos/

# 2. 检查.app内部结构
ls -la build/Build/Products/Release-iphoneos/GitHub.app/

# 3. 检查Info.plist是否存在
ls -la build/Build/Products/Release-iphoneos/GitHub.app/Info.plist

# 4. 手动导出IPA测试
mkdir -p Payload
cp -R build/Build/Products/Release-iphoneos/GitHub.app Payload/
zip -r GitHub.ipa Payload
ls -la GitHub.ipa
```

**解决方案**：
- 检查 `PRODUCT_NAME` 配置是否正确
- 确保编译配置为 `Release`
- 检查 `Info.plist` 是否在 Copy Bundle Resources 中

---

### 3.5 README 日志更新失败

**现象**：生产流水线 `update-changelog` Job 失败，日志显示 README 操作失败。

**可能原因**：
1. `update-changelog.sh` 脚本参数错误
2. README.md 文件不存在
3. Git 提交权限不足
4. 日志标记缺失

**排查步骤**：
```bash
# 1. 检查README.md是否存在
ls -la README.md

# 2. 检查日志标记是否存在
grep "CHANGELOG_START" README.md
grep "CHANGELOG_END" README.md

# 3. 本地手动测试日志更新脚本
bash scripts/update-changelog.sh \
  --version "1.0.0" \
  --commit "abc1234" \
  --build-time "2026-09-09 12:00:00" \
  --sha256 "testsha256hash" \
  --desc "测试更新日志"

# 4. 检查Git配置
git config user.name
git config user.email
```

**解决方案**：
- 确保 README.md 中包含 `<!-- CHANGELOG_START -->` 和 `<!-- CHANGELOG_END -->` 标记
- 检查 `GITHUB_TOKEN` 权限（默认有读写权限）
- 本地测试脚本通过后再提交

---

### 3.6 PR 警告门禁拦截

**现象**：PR 校验流水线失败，日志显示编译警告数量超过阈值。

**可能原因**：
1. 代码中存在过多编译警告
2. 警告阈值设置过低（默认10）

**排查步骤**：
```bash
# 1. 本地编译并统计警告
xcodebuild \
  -project GitHub.xcodeproj \
  -scheme GitHub \
  -configuration Debug \
  -sdk iphoneos \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | tee build.log

# 2. 统计警告数量
grep -c "warning:" build.log

# 3. 查看警告详情
grep "warning:" build.log
```

**解决方案**：
- 修复代码中的编译警告（推荐）
- 如确需调整阈值，修改 `pr-quality-gate.yml` 中的 `WARNING_THRESHOLD` 环境变量
- 阈值调整必须经过 PR 评审

---

### 3.7 Artifacts 下载失败

**现象**：无法从 GitHub Actions 下载构建产物。

**可能原因**：
1. Artifacts 已过期（默认保留30天）
2. 流水线运行失败，未生成产物
3. 浏览器或网络问题

**排查步骤**：
1. 进入仓库 Actions 页面
2. 选择对应的流水线运行记录
3. 检查页面底部 Artifacts 区域是否有产物
4. 检查 Artifacts 是否显示过期标记

**解决方案**：
- 如已过期，重新触发流水线生成新产物
- 如流水线失败，先修复构建问题
- 检查网络连接，尝试使用其他浏览器

---

## 四、流水线性能优化

### 4.1 缓存机制

本项目已内置以下缓存策略，显著缩短构建时间：

| 缓存类型 | 缓存路径 | 缓存Key | 预计节省时间 |
|---------|---------|---------|------------|
| Swift包依赖 | `~/Library/Caches/org.swift.swiftpm` | `{os}-spm-{hash}` | 30-60秒 |
| 编译产物 | `~/Library/Developer/Xcode/DerivedData` | `{os}-xcode-{sha}` | 60-120秒 |

### 4.2 并行执行

生产流水线采用串行依赖设计，确保版本递增 → 编译 → 日志更新的顺序正确性。

PR 校验流水线的两个 Job（编译校验、Shell脚本检查）并行执行，缩短校验时间。

### 4.3 构建耗时监控

每次生产构建自动计算总耗时，并写入制品元数据 JSON：

```json
{
  "build_duration_seconds": 180,
  "build_duration_human": "3分0秒"
}
```

可通过元数据文件追踪构建性能变化趋势。

---

## 五、运维操作手册

### 5.1 手动触发生产构建

1. 进入仓库 Actions 页面
2. 选择「生产构建流水线」
3. 点击「Run workflow」按钮
4. 选择 `main` 分支
5. 点击「Run workflow」确认

### 5.2 查看构建日志

1. 进入仓库 Actions 页面
2. 选择对应的流水线运行记录
3. 点击具体的 Job 名称
4. 展开各个 Step 查看详细日志

### 5.3 下载构建产物

1. 进入仓库 Actions 页面
2. 选择成功的生产构建运行记录
3. 滚动到页面底部 Artifacts 区域
4. 点击 `GitHub-iOS-IPA-v{版本号}` 下载 IPA
5. 点击 `GitHub-iOS-Metadata-v{版本号}` 下载元数据

### 5.4 取消正在运行的构建

1. 进入仓库 Actions 页面
2. 选择正在运行的流水线
3. 点击右上角「Cancel workflow」按钮

### 5.5 重新运行失败的构建

1. 进入仓库 Actions 页面
2. 选择失败的流水线运行记录
3. 点击右上角「Re-run jobs」按钮
4. 选择「Re-run all jobs」或「Re-run failed jobs」

---

## 六、紧急回滚方案

### 6.1 版本号回滚

如果版本递增出现问题，需要回滚版本号：

```bash
# 1. 查看最近的版本变更提交
git log --oneline -5 -- GitHub/Info.plist

# 2. 回滚到上一个版本
git revert <版本变更的commit_hash>

# 3. 推送到main分支
git push origin main
```

### 6.2 README 日志回滚

如果更新日志出现问题：

```bash
# 1. 查看README变更历史
git log --oneline -5 -- README.md

# 2. 回滚README
git revert <README变更的commit_hash>

# 3. 推送
git push origin main
```

### 6.3 流水线配置回滚

如果 CI 配置修改导致流水线异常：

```bash
# 1. 查看workflow变更历史
git log --oneline -5 -- .github/workflows/

# 2. 回滚到上一个稳定版本
git revert <workflow变更的commit_hash>

# 3. 推送
git push origin main
```

---

## 七、联系与支持

如遇到本文档未覆盖的问题，请按以下顺序排查：

1. **检查流水线日志**：大多数问题都能在详细日志中找到原因
2. **本地复现**：在本地 macOS 环境执行相同命令，复现问题
3. **检查Git历史**：查看最近的代码变更，定位引入问题的提交
4. **查阅文档**：阅读《仓库环境配置手册》和《制品说明文档》
