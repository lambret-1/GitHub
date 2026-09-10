import SwiftUI

// MARK: - 高级筛选面板（可视化查询构造器）

struct AdvancedFilterView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var searchType: SearchView.SearchTab
    @Binding var filterConfig: FilterConfiguration
    var onApply: (FilterConfiguration) -> Void

    var body: some View {
        NavigationView {
            Form {
                if searchType == .repositories {
                    repositoryFilterSection
                } else {
                    userFilterSection
                }

                // 预览生成的查询语句
                Section("查询预览") {
                    Text(filterConfig.buildQuery())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                // 重置按钮
                Section {
                    Button(action: {
                        filterConfig.reset()
                    }) {
                        HStack {
                            Spacer()
                            Text("重置所有筛选条件")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("高级筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        onApply(filterConfig)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - 仓库筛选条件

    private var repositoryFilterSection: some View {
        Group {
            // 语言筛选
            Section("语言") {
                Picker("编程语言", selection: $filterConfig.language) {
                    Text("全部").tag("")
                    ForEach(CommonLanguages.all, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
            }

            // Star 数量
            Section("Star 数量") {
                HStack {
                    Text("最少")
                    Spacer()
                    TextField("0", text: $filterConfig.minStars)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("最多")
                    Spacer()
                    TextField("不限", text: $filterConfig.maxStars)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            // Fork 数量
            Section("Fork 数量") {
                HStack {
                    Text("最少")
                    Spacer()
                    TextField("0", text: $filterConfig.minForks)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("最多")
                    Spacer()
                    TextField("不限", text: $filterConfig.maxForks)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            // 时间筛选
            Section("创建时间") {
                DatePicker("从", selection: $filterConfig.createdFrom, displayedComponents: .date)
                DatePicker("到", selection: $filterConfig.createdTo, displayedComponents: .date)
            }

            Section("更新时间") {
                DatePicker("从", selection: $filterConfig.pushedFrom, displayedComponents: .date)
                DatePicker("到", selection: $filterConfig.pushedTo, displayedComponents: .date)
            }

            // 许可证
            Section("许可证") {
                Picker("许可证类型", selection: $filterConfig.license) {
                    Text("全部").tag("")
                    ForEach(CommonLicenses.all, id: \.self) { license in
                        Text(license).tag(license)
                    }
                }
            }

            // 仓库属性
            Section("仓库属性") {
                Toggle("有议题 (Issues)", isOn: $filterConfig.hasIssues)
                Toggle("有 Wiki", isOn: $filterConfig.hasWiki)
                Toggle("有项目 (Projects)", isOn: $filterConfig.hasProjects)
                Toggle("已归档", isOn: $filterConfig.archived)
            }

            // 仓库类型
            Section("仓库类型") {
                Picker("类型", selection: $filterConfig.repoType) {
                    Text("全部").tag("")
                    Text("公开").tag("public")
                    Text("私有").tag("private")
                    Text("Fork").tag("fork")
                    Text("源仓库").tag("source")
                }
                .pickerStyle(.menu)
            }

            // 主题标签
            Section("主题标签 (Topics)") {
                TextField("输入主题标签，用逗号分隔", text: $filterConfig.topics)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            // 排序方式
            Section("排序方式") {
                Picker("排序", selection: $filterConfig.sortBy) {
                    Text("最佳匹配").tag("")
                    Text("Star 数").tag("stars")
                    Text("Fork 数").tag("forks")
                    Text("更新时间").tag("updated")
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - 用户筛选条件

    private var userFilterSection: some View {
        Group {
            // 用户类型
            Section("用户类型") {
                Picker("类型", selection: $filterConfig.userType) {
                    Text("全部").tag("")
                    Text("个人用户").tag("user")
                    Text("组织").tag("org")
                }
                .pickerStyle(.menu)
            }

            // 仓库数量
            Section("仓库数量") {
                HStack {
                    Text("最少")
                    Spacer()
                    TextField("0", text: $filterConfig.minRepos)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("最多")
                    Spacer()
                    TextField("不限", text: $filterConfig.maxRepos)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            // 关注者数量
            Section("关注者数量") {
                HStack {
                    Text("最少")
                    Spacer()
                    TextField("0", text: $filterConfig.minFollowers)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("最多")
                    Spacer()
                    TextField("不限", text: $filterConfig.maxFollowers)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            // 位置
            Section("位置") {
                TextField("输入位置，如：Beijing、China", text: $filterConfig.location)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            // 创建时间
            Section("创建时间") {
                DatePicker("从", selection: $filterConfig.userCreatedFrom, displayedComponents: .date)
                DatePicker("到", selection: $filterConfig.userCreatedTo, displayedComponents: .date)
            }

            // 用户属性
            Section("用户属性") {
                Toggle("可雇佣 (Hireable)", isOn: $filterConfig.isHireable)
            }

            // 排序方式
            Section("排序方式") {
                Picker("排序", selection: $filterConfig.userSortBy) {
                    Text("最佳匹配").tag("")
                    Text("关注者数").tag("followers")
                    Text("仓库数").tag("repositories")
                    Text("加入时间").tag("joined")
                }
                .pickerStyle(.menu)
            }
        }
    }
}

// MARK: - 筛选配置模型

struct FilterConfiguration {
    // 仓库筛选
    var language: String = ""
    var minStars: String = ""
    var maxStars: String = ""
    var minForks: String = ""
    var maxForks: String = ""
    var createdFrom: Date = Date()
    var createdTo: Date = Date()
    var pushedFrom: Date = Date()
    var pushedTo: Date = Date()
    var license: String = ""
    var hasIssues: Bool = false
    var hasWiki: Bool = false
    var hasProjects: Bool = false
    var archived: Bool = false
    var repoType: String = ""
    var topics: String = ""
    var sortBy: String = ""

    // 用户筛选
    var userType: String = ""
    var minRepos: String = ""
    var maxRepos: String = ""
    var minFollowers: String = ""
    var maxFollowers: String = ""
    var location: String = ""
    var userCreatedFrom: Date = Date()
    var userCreatedTo: Date = Date()
    var isHireable: Bool = false
    var userSortBy: String = ""

    // 标记是否使用了创建/更新时间筛选
    var useCreatedRange: Bool = false
    var usePushedRange: Bool = false
    var useUserCreatedRange: Bool = false

    mutating func reset() {
        self = FilterConfiguration()
    }

    func buildQuery(baseQuery: String = "") -> String {
        var parts: [String] = []

        if !baseQuery.isEmpty {
            parts.append(baseQuery)
        }

        // 仓库筛选
        if !language.isEmpty {
            parts.append("language:\(language)")
        }
        if !minStars.isEmpty {
            parts.append("stars:>=\(minStars)")
        }
        if !maxStars.isEmpty {
            parts.append("stars:<=\(maxStars)")
        }
        if !minForks.isEmpty {
            parts.append("forks:>=\(minForks)")
        }
        if !maxForks.isEmpty {
            parts.append("forks:<=\(maxForks)")
        }
        if useCreatedRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parts.append("created:\(formatter.string(from: createdFrom))..\(formatter.string(from: createdTo))")
        }
        if usePushedRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parts.append("pushed:\(formatter.string(from: pushedFrom))..\(formatter.string(from: pushedTo))")
        }
        if !license.isEmpty {
            parts.append("license:\(license)")
        }
        if hasIssues {
            parts.append("has:issues")
        }
        if hasWiki {
            parts.append("has:wiki")
        }
        if hasProjects {
            parts.append("has:projects")
        }
        if archived {
            parts.append("archived:true")
        }
        if !repoType.isEmpty {
            parts.append("type:\(repoType)")
        }
        if !topics.isEmpty {
            let topicList = topics.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            for topic in topicList {
                parts.append("topic:\(topic)")
            }
        }

        // 用户筛选
        if !userType.isEmpty {
            parts.append("type:\(userType)")
        }
        if !minRepos.isEmpty {
            parts.append("repos:>=\(minRepos)")
        }
        if !maxRepos.isEmpty {
            parts.append("repos:<=\(maxRepos)")
        }
        if !minFollowers.isEmpty {
            parts.append("followers:>=\(minFollowers)")
        }
        if !maxFollowers.isEmpty {
            parts.append("followers:<=\(maxFollowers)")
        }
        if !location.isEmpty {
            parts.append("location:\(location)")
        }
        if useUserCreatedRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parts.append("created:\(formatter.string(from: userCreatedFrom))..\(formatter.string(from: userCreatedTo))")
        }
        if isHireable {
            parts.append("is:hireable")
        }

        return parts.joined(separator: " ")
    }

    func getSortParameter() -> String {
        if !sortBy.isEmpty {
            return sortBy
        }
        if !userSortBy.isEmpty {
            return userSortBy
        }
        return ""
    }

    var hasActiveFilters: Bool {
        return !language.isEmpty ||
               !minStars.isEmpty || !maxStars.isEmpty ||
               !minForks.isEmpty || !maxForks.isEmpty ||
               !license.isEmpty || hasIssues || hasWiki || hasProjects ||
               archived || !repoType.isEmpty || !topics.isEmpty ||
               !userType.isEmpty || !minRepos.isEmpty || !maxRepos.isEmpty ||
               !minFollowers.isEmpty || !maxFollowers.isEmpty ||
               !location.isEmpty || isHireable || useCreatedRange ||
               usePushedRange || useUserCreatedRange
    }
}

// MARK: - 常用语言列表

enum CommonLanguages {
    static let all: [String] = [
        "Swift", "Objective-C", "JavaScript", "TypeScript", "Python", "Java", "Kotlin",
        "Go", "Rust", "C", "C++", "C#", "Ruby", "PHP", "Dart", "Flutter",
        "HTML", "CSS", "SCSS", "Shell", "Bash", "PowerShell",
        "SQL", "MySQL", "PostgreSQL", "MongoDB", "Redis",
        "Dockerfile", "Makefile", "CMake", "Gradle",
        "Markdown", "JSON", "XML", "YAML", "TOML",
        "Vue", "React", "Angular", "Svelte",
        "Node.js", "Deno", "Bun",
        "Lua", "Perl", "R", "Scala", "Clojure", "Elixir", "Haskell", "Erlang"
    ]
}

// MARK: - 常用许可证列表

enum CommonLicenses {
    static let all: [String] = [
        "mit", "apache-2.0", "gpl-3.0", "gpl-2.0", "lgpl-3.0", "lgpl-2.1",
        "bsd-3-clause", "bsd-2-clause", "mpl-2.0", "agpl-3.0",
        "unlicense", "cc0-1.0", "epl-2.0", "epl-1.0",
        "artistic-2.0", "isc", "zlib", "wtfpl"
    ]
}
