# Shared 共享组件模块

## 模块说明
本模块存放跨模块共享的可复用UI组件，供应用各视图模块统一调用，确保UI风格一致性。

## 文件清单

| 文件名 | 功能说明 |
|--------|----------|
| `SearchBar.swift` | 搜索栏组件，基于UIKit的UISearchBar封装，与主页仓库搜索框样式一致，支持文本绑定、占位符、搜索按钮回调 |

## 功能参数说明

### SearchBar 搜索栏
- `text: Binding<String>` - 搜索文本双向绑定
- `placeholder: String` - 占位符文本
- `onSearchButtonClicked: (() -> Void)?` - 搜索按钮点击回调（可选）
- 内部实现：
  - `Coordinator` - UIKit协调器类，实现UISearchBarDelegate协议
    - `text: Binding<String>` - 文本绑定
    - `onSearchButtonClicked: (() -> Void)?` - 搜索按钮回调
    - `searchBar(_:textDidChange:)` - 文本变化时更新绑定
    - `searchBarSearchButtonClicked(_:)` - 搜索按钮点击时收起键盘并触发回调
  - `makeCoordinator()` - 创建协调器
  - `makeUIView(context:)` - 创建UISearchBar实例，设置样式为minimal，禁用自动大写和自动纠错
  - `updateUIView(_:context:)` - 更新UIView文本

## 核心功能
1. **统一搜索样式**：基于UIKit的UISearchBar封装，与主页仓库搜索框样式一致
2. **文本双向绑定**：使用@Binding实现SwiftUI与UIKit的文本双向同步
3. **占位符支持**：支持自定义占位符文本
4. **搜索按钮回调**：支持搜索按钮点击回调，点击后自动收起键盘
5. **minimal样式**：使用UISearchBar.Style.minimal样式，简洁美观
6. **禁用自动大写**：设置autocapitalizationType为.none，避免搜索词自动大写
7. **禁用自动纠错**：设置autocorrectionType为.no，避免搜索词自动纠错
8. **深色模式适配**：UIKit组件自动适配深色模式
9. **全局复用**：可在任何需要搜索框的视图中使用

## 使用示例

```swift
// 基本使用
SearchBar(text: $searchText, placeholder: "搜索仓库")

// 带搜索按钮回调
SearchBar(text: $searchText, placeholder: "搜索代码") {
    performSearch()
}
```

## 依赖模块
- `SwiftUI` - SwiftUI框架
- `UIKit` - UIKit框架（UISearchBar）
