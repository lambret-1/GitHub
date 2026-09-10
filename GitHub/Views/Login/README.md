# 登录页面目录

本目录存放应用登录相关的视图文件。

## 文件说明

### LoginView.swift
**登录页面视图**

**功能参数说明：**

| 参数/属性 | 中文释义 | 说明 |
|-----------|---------|------|
| `token` | Token 输入 | 用户输入的 GitHub Personal Access Token |
| `isLoading` | 加载状态 | 登录请求进行中的状态标记 |
| `errorMessage` | 错误信息 | 登录失败时的错误提示文本 |
| `showToken` | 显示 Token | 控制 Token 输入框是否明文显示 |
| `appIcon` | 应用图标 | 登录页面顶部显示的应用图标 |

**页面元素：**
- 应用图标（AppIconImage）
- 应用名称："GitHub 中文客户端"
- Token 输入框（支持显示/隐藏切换、剪贴板粘贴）
- 登录按钮
- 错误提示区域

**登录流程：**
1. 用户输入 Token
2. 点击登录按钮
3. 调用 GitHubAPI.getUserInfo() 验证 Token
4. 验证成功后保存 Token 到 Keychain
5. 跳转到主界面（仓库列表）
6. 验证失败显示错误信息

**安全特性：**
- Token 输入框默认密文显示
- 支持一键显示/隐藏 Token
- Token 安全存储在 Keychain 中
- 禁止在日志中输出 Token
