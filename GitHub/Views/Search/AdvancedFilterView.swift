import SwiftUI

// MARK: - 高级筛选面板

struct AdvancedFilterView: View {
    @Binding var repoFilter: RepoFilterState
    @Binding var userFilter: UserFilterState
    let selectedTab: SearchView.SearchTab
    var onApply: () -> Void
    var onReset: () -> Void

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                if selectedTab == .repositories {
                    repoFilterSections
                } else {
                    userFilterSections
                }
            }
            .navigationTitle("高级筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        onReset()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        onApply()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - 仓库筛选部分

    private var repoFilterSections: some View {
        Group {
            // 搜索范围
            Section("搜索范围") {
                Toggle("仓库名称", isOn: $repoFilter.searchInName)
                Toggle("仓库描述", isOn: $repoFilter.searchInDescription)
                Toggle("README 文件", isOn: $repoFilter.searchInReadme)
            }

            // 仓库属性
            Section("仓库属性") {
                Toggle("仅公开仓库", isOn: $repoFilter.isPublic)
                Toggle("仅私有仓库", isOn: $repoFilter.isPrivate)

                HStack {
                    Text("归档状态")
                    Spacer()
                    Picker("归档状态", selection: Binding(
                        get: { repoFilter.isArchived ?? 2 as Int? },
                        set: { newValue in
                            repoFilter.isArchived = (newValue == 2 ? nil : (newValue == 1))
                        }
                    )) {
                        Text("不限").tag(2 as Int?)
                        Text("仅已归档").tag(1 as Int?)
                        Text("仅未归档").tag(0 as Int?)
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text("模板仓库")
                    Spacer()
                    Picker("模板仓库", selection: Binding(
                        get: { repoFilter.isTemplate ?? 2 as Int? },
                        set: { newValue in
                            repoFilter.isTemplate = (newValue == 2 ? nil : (newValue == 1))
                        }
                    )) {
                        Text("不限").tag(2 as Int?)
                        Text("仅模板").tag(1 as Int?)
                        Text("非模板").tag(0 as Int?)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            // 编程语言
            Section("编程语言") {
                NavigationLink(destination: LanguagePickerView(selectedLanguage: $repoFilter.language)) {
                    HStack {
                        Text("语言")
                        Spacer()
                        if let language = repoFilter.language {
                            Text(language).foregroundColor(.secondary)
                        } else {
                            Text("不限").foregroundColor(.gray)
                        }
                    }
                }
            }

            // 主题和许可证
            Section("主题与许可证") {
                HStack {
                    Text("主题")
                    TextField("如: ios, swiftui", text: Binding(
                        get: { repoFilter.topic ?? "" },
                        set: { repoFilter.topic = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                }

                NavigationLink(destination: LicensePickerView(selectedLicense: $repoFilter.license)) {
                    HStack {
                        Text("许可证")
                        Spacer()
                        if let license = repoFilter.license {
                            Text(license.uppercased()).foregroundColor(.secondary)
                        } else {
                            Text("不限").foregroundColor(.gray)
                        }
                    }
                }
            }

            // 所有者
            Section("所有者") {
                HStack {
                    Text("用户")
                    TextField("用户名", text: Binding(
                        get: { repoFilter.user ?? "" },
                        set: { repoFilter.user = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                }
                HStack {
                    Text("组织")
                    TextField("组织名", text: Binding(
                        get: { repoFilter.org ?? "" },
                        set: { repoFilter.org = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                }
            }

            // 数值范围
            Section("数值范围") {
                HStack {
                    Text("最少 Star 数")
                    Spacer()
                    Picker("Star 数", selection: Binding(
                        get: { repoFilter.minStars ?? 0 },
                        set: { repoFilter.minStars = $0 == 0 ? nil : $0 }
                    )) {
                        ForEach(FilterOptions.starOptions, id: \.self) { value in
                            Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text("最少 Fork 数")
                    Spacer()
                    Picker("Fork 数", selection: Binding(
                        get: { repoFilter.minForks ?? 0 },
                        set: { repoFilter.minForks = $0 == 0 ? nil : $0 }
                    )) {
                        ForEach(FilterOptions.forkOptions, id: \.self) { value in
                            Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text("最小大小(KB)")
                    Spacer()
                    Picker("大小", selection: Binding(
                        get: { repoFilter.minSizeKB ?? 0 },
                        set: { repoFilter.minSizeKB = $0 == 0 ? nil : $0 }
                    )) {
                        Text("不限").tag(0)
                        Text(">= 1 KB").tag(1)
                        Text(">= 10 KB").tag(10)
                        Text(">= 100 KB").tag(100)
                        Text(">= 1 MB").tag(1024)
                        Text(">= 10 MB").tag(10240)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            // 时间范围
            Section("时间范围") {
                DatePicker("创建时间不早于", selection: Binding(
                    get: { repoFilter.createdAfter ?? Date() },
                    set: { repoFilter.createdAfter = $0 }
                ), displayedComponents: .date)
                .onAppear {
                    if repoFilter.createdAfter == nil {
                        repoFilter.createdAfter = Calendar.current.date(byAdding: .year, value: -1, to: Date())
                    }
                }

                Button("清除创建时间筛选") {
                    repoFilter.createdAfter = nil
                }
                .foregroundColor(.red)
                .disabled(repoFilter.createdAfter == nil)

                DatePicker("最近推送不早于", selection: Binding(
                    get: { repoFilter.pushedAfter ?? Date() },
                    set: { repoFilter.pushedAfter = $0 }
                ), displayedComponents: .date)
                .onAppear {
                    if repoFilter.pushedAfter == nil {
                        repoFilter.pushedAfter = Calendar.current.date(byAdding: .month, value: -3, to: Date())
                    }
                }

                Button("清除推送时间筛选") {
                    repoFilter.pushedAfter = nil
                }
                .foregroundColor(.red)
                .disabled(repoFilter.pushedAfter == nil)
            }
        }
    }

    // MARK: - 用户筛选部分

    private var userFilterSections: some View {
        Group {
            // 搜索范围
            Section("搜索范围") {
                Toggle("用户名", isOn: $userFilter.searchInLogin)
                Toggle("全名", isOn: $userFilter.searchInFullName)
                Toggle("邮箱", isOn: $userFilter.searchInEmail)
            }

            // 用户类型
            Section("用户类型") {
                Picker("类型", selection: Binding(
                    get: { userFilter.userType?.rawValue ?? "不限" },
                    set: { newValue in
                        userFilter.userType = newValue == "不限" ? nil : UserFilterState.UserType(rawValue: newValue)
                    }
                )) {
                    Text("不限").tag("不限")
                    Text("仅用户").tag("用户")
                    Text("仅组织").tag("组织")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // 位置和语言
            Section("位置与语言") {
                HStack {
                    Text("位置")
                    TextField("如: Beijing, China", text: Binding(
                        get: { userFilter.location ?? "" },
                        set: { userFilter.location = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                }

                NavigationLink(destination: LanguagePickerView(selectedLanguage: $userFilter.language)) {
                    HStack {
                        Text("主要语言")
                        Spacer()
                        if let language = userFilter.language {
                            Text(language).foregroundColor(.secondary)
                        } else {
                            Text("不限").foregroundColor(.gray)
                        }
                    }
                }
            }

            // 数值范围
            Section("数值范围") {
                HStack {
                    Text("最少仓库数")
                    Spacer()
                    Picker("仓库数", selection: Binding(
                        get: { userFilter.minRepos ?? 0 },
                        set: { userFilter.minRepos = $0 == 0 ? nil : $0 }
                    )) {
                        ForEach(FilterOptions.repoOptions, id: \.self) { value in
                            Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text("最少关注者")
                    Spacer()
                    Picker("关注者", selection: Binding(
                        get: { userFilter.minFollowers ?? 0 },
                        set: { userFilter.minFollowers = $0 == 0 ? nil : $0 }
                    )) {
                        ForEach(FilterOptions.followerOptions, id: \.self) { value in
                            Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text("最少关注数")
                    Spacer()
                    Picker("关注数", selection: Binding(
                        get: { userFilter.minFollowing ?? 0 },
                        set: { userFilter.minFollowing = $0 == 0 ? nil : $0 }
                    )) {
                        ForEach(FilterOptions.followerOptions, id: \.self) { value in
                            Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            // 时间范围
            Section("时间范围") {
                DatePicker("注册时间不早于", selection: Binding(
                    get: { userFilter.createdAfter ?? Date() },
                    set: { userFilter.createdAfter = $0 }
                ), displayedComponents: .date)
                .onAppear {
                    if userFilter.createdAfter == nil {
                        userFilter.createdAfter = Calendar.current.date(byAdding: .year, value: -1, to: Date())
                    }
                }

                Button("清除注册时间筛选") {
                    userFilter.createdAfter = nil
                }
                .foregroundColor(.red)
                .disabled(userFilter.createdAfter == nil)
            }
        }
    }
}

// MARK: - 语言选择器

struct LanguagePickerView: View {
    @Binding var selectedLanguage: String?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        List {
            Button(action: {
                selectedLanguage = nil
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Text("不限")
                    Spacer()
                    if selectedLanguage == nil {
                        Image(systemName: "checkmark").foregroundColor(.blue)
                    }
                }
            }

            ForEach(FilterOptions.languages, id: \.self) { language in
                Button(action: {
                    selectedLanguage = language
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(language)
                        Spacer()
                        if selectedLanguage == language {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("选择语言")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 许可证选择器

struct LicensePickerView: View {
    @Binding var selectedLicense: String?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        List {
            Button(action: {
                selectedLicense = nil
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Text("不限")
                    Spacer()
                    if selectedLicense == nil {
                        Image(systemName: "checkmark").foregroundColor(.blue)
                    }
                }
            }

            ForEach(FilterOptions.licenses, id: \.self) { license in
                Button(action: {
                    selectedLicense = license
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(license.uppercased())
                        Spacer()
                        if selectedLicense == license {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("选择许可证")
        .navigationBarTitleDisplayMode(.inline)
    }
}
