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
                content
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
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if selectedTab == .repositories {
            repoSearchScopeSection
            repoAttributesSection
            repoLanguageSection
            repoTopicLicenseSection
            repoOwnerSection
            repoNumericSection
            repoDateSection
        } else {
            userSearchScopeSection
            userTypeSection
            userLocationLanguageSection
            userNumericSection
            userDateSection
        }
    }

    // MARK: - 辅助方法

    private func optionalIntBinding(_ value: Binding<Int?>, defaultValue: Int = 0) -> Binding<Int> {
        return Binding<Int>(
            get: { value.wrappedValue ?? defaultValue },
            set: { newValue in
                value.wrappedValue = newValue == defaultValue ? nil : newValue
            }
        )
    }

    private func optionalStringBinding(_ value: Binding<String?>) -> Binding<String> {
        return Binding<String>(
            get: { value.wrappedValue ?? "" },
            set: { newValue in
                value.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private func triStateBinding(_ value: Binding<Bool?>) -> Binding<Int> {
        return Binding<Int>(
            get: {
                if let v = value.wrappedValue {
                    return v ? 1 : 0
                }
                return 2
            },
            set: { newValue in
                value.wrappedValue = newValue == 2 ? nil : (newValue == 1)
            }
        )
    }
}

// MARK: - 仓库筛选部分

extension AdvancedFilterView {
    private var repoSearchScopeSection: some View {
        Section("搜索范围") {
            Toggle("仓库名称", isOn: $repoFilter.searchInName)
            Toggle("仓库描述", isOn: $repoFilter.searchInDescription)
            Toggle("README 文件", isOn: $repoFilter.searchInReadme)
        }
    }

    private var repoAttributesSection: some View {
        Section("仓库属性") {
            Toggle("仅公开仓库", isOn: $repoFilter.isPublic)
            Toggle("仅私有仓库", isOn: $repoFilter.isPrivate)
            archivedPicker
            templatePicker
        }
    }

    private var archivedPicker: some View {
        HStack {
            Text("归档状态")
            Spacer()
            Picker("归档状态", selection: triStateBinding($repoFilter.isArchived)) {
                Text("不限").tag(2)
                Text("仅已归档").tag(1)
                Text("仅未归档").tag(0)
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var templatePicker: some View {
        HStack {
            Text("模板仓库")
            Spacer()
            Picker("模板仓库", selection: triStateBinding($repoFilter.isTemplate)) {
                Text("不限").tag(2)
                Text("仅模板").tag(1)
                Text("非模板").tag(0)
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var repoLanguageSection: some View {
        Section("编程语言") {
            NavigationLink(destination: LanguagePickerView(selectedLanguage: $repoFilter.language)) {
                HStack {
                    Text("语言")
                    Spacer()
                    languageText
                }
            }
        }
    }

    private var languageText: some View {
        Group {
            if let language = repoFilter.language {
                Text(language).foregroundColor(.secondary)
            } else {
                Text("不限").foregroundColor(.gray)
            }
        }
    }

    private var repoTopicLicenseSection: some View {
        Section("主题与许可证") {
            topicInput
            NavigationLink(destination: LicensePickerView(selectedLicense: $repoFilter.license)) {
                HStack {
                    Text("许可证")
                    Spacer()
                    licenseText
                }
            }
        }
    }

    private var topicInput: some View {
        HStack {
            Text("主题")
            TextField("如: ios, swiftui", text: optionalStringBinding($repoFilter.topic))
                .multilineTextAlignment(.trailing)
                .autocapitalization(.none)
        }
    }

    private var licenseText: some View {
        Group {
            if let license = repoFilter.license {
                Text(license.uppercased()).foregroundColor(.secondary)
            } else {
                Text("不限").foregroundColor(.gray)
            }
        }
    }

    private var repoOwnerSection: some View {
        Section("所有者") {
            userInput
            orgInput
        }
    }

    private var userInput: some View {
        HStack {
            Text("用户")
            TextField("用户名", text: optionalStringBinding($repoFilter.user))
                .multilineTextAlignment(.trailing)
                .autocapitalization(.none)
        }
    }

    private var orgInput: some View {
        HStack {
            Text("组织")
            TextField("组织名", text: optionalStringBinding($repoFilter.org))
                .multilineTextAlignment(.trailing)
                .autocapitalization(.none)
        }
    }

    private var repoNumericSection: some View {
        Section("数值范围") {
            starsPicker
            forksPicker
            sizePicker
        }
    }

    private var starsPicker: some View {
        HStack {
            Text("最少 Star 数")
            Spacer()
            Picker("Star 数", selection: optionalIntBinding($repoFilter.minStars)) {
                ForEach(FilterOptions.starOptions, id: \.self) { value in
                    Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var forksPicker: some View {
        HStack {
            Text("最少 Fork 数")
            Spacer()
            Picker("Fork 数", selection: optionalIntBinding($repoFilter.minForks)) {
                ForEach(FilterOptions.forkOptions, id: \.self) { value in
                    Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var sizePicker: some View {
        HStack {
            Text("最小大小(KB)")
            Spacer()
            Picker("大小", selection: optionalIntBinding($repoFilter.minSizeKB)) {
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

    private var repoDateSection: some View {
        Section("时间范围") {
            createdDatePicker
            clearCreatedButton
            pushedDatePicker
            clearPushedButton
        }
    }

    private var createdDatePicker: some View {
        DatePicker("创建时间不早于", selection: Binding(
            get: { repoFilter.createdAfter ?? Date() },
            set: { repoFilter.createdAfter = $0 }
        ), displayedComponents: .date)
        .onAppear {
            if repoFilter.createdAfter == nil {
                repoFilter.createdAfter = Calendar.current.date(byAdding: .year, value: -1, to: Date())
            }
        }
    }

    private var clearCreatedButton: some View {
        Button("清除创建时间筛选") {
            repoFilter.createdAfter = nil
        }
        .foregroundColor(.red)
        .disabled(repoFilter.createdAfter == nil)
    }

    private var pushedDatePicker: some View {
        DatePicker("最近推送不早于", selection: Binding(
            get: { repoFilter.pushedAfter ?? Date() },
            set: { repoFilter.pushedAfter = $0 }
        ), displayedComponents: .date)
        .onAppear {
            if repoFilter.pushedAfter == nil {
                repoFilter.pushedAfter = Calendar.current.date(byAdding: .month, value: -3, to: Date())
            }
        }
    }

    private var clearPushedButton: some View {
        Button("清除推送时间筛选") {
            repoFilter.pushedAfter = nil
        }
        .foregroundColor(.red)
        .disabled(repoFilter.pushedAfter == nil)
    }
}

// MARK: - 用户筛选部分

extension AdvancedFilterView {
    private var userSearchScopeSection: some View {
        Section("搜索范围") {
            Toggle("用户名", isOn: $userFilter.searchInLogin)
            Toggle("全名", isOn: $userFilter.searchInFullName)
            Toggle("邮箱", isOn: $userFilter.searchInEmail)
        }
    }

    private var userTypeSection: some View {
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
    }

    private var userLocationLanguageSection: some View {
        Section("位置与语言") {
            locationInput
            NavigationLink(destination: LanguagePickerView(selectedLanguage: $userFilter.language)) {
                HStack {
                    Text("主要语言")
                    Spacer()
                    userLanguageText
                }
            }
        }
    }

    private var locationInput: some View {
        HStack {
            Text("位置")
            TextField("如: Beijing, China", text: optionalStringBinding($userFilter.location))
                .multilineTextAlignment(.trailing)
        }
    }

    private var userLanguageText: some View {
        Group {
            if let language = userFilter.language {
                Text(language).foregroundColor(.secondary)
            } else {
                Text("不限").foregroundColor(.gray)
            }
        }
    }

    private var userNumericSection: some View {
        Section("数值范围") {
            reposPicker
            followersPicker
            followingPicker
        }
    }

    private var reposPicker: some View {
        HStack {
            Text("最少仓库数")
            Spacer()
            Picker("仓库数", selection: optionalIntBinding($userFilter.minRepos)) {
                ForEach(FilterOptions.repoOptions, id: \.self) { value in
                    Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var followersPicker: some View {
        HStack {
            Text("最少关注者")
            Spacer()
            Picker("关注者", selection: optionalIntBinding($userFilter.minFollowers)) {
                ForEach(FilterOptions.followerOptions, id: \.self) { value in
                    Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var followingPicker: some View {
        HStack {
            Text("最少关注数")
            Spacer()
            Picker("关注数", selection: optionalIntBinding($userFilter.minFollowing)) {
                ForEach(FilterOptions.followerOptions, id: \.self) { value in
                    Text(value == 0 ? "不限" : ">= \(value)").tag(value)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var userDateSection: some View {
        Section("时间范围") {
            userCreatedDatePicker
            clearUserCreatedButton
        }
    }

    private var userCreatedDatePicker: some View {
        DatePicker("注册时间不早于", selection: Binding(
            get: { userFilter.createdAfter ?? Date() },
            set: { userFilter.createdAfter = $0 }
        ), displayedComponents: .date)
        .onAppear {
            if userFilter.createdAfter == nil {
                userFilter.createdAfter = Calendar.current.date(byAdding: .year, value: -1, to: Date())
            }
        }
    }

    private var clearUserCreatedButton: some View {
        Button("清除注册时间筛选") {
            userFilter.createdAfter = nil
        }
        .foregroundColor(.red)
        .disabled(userFilter.createdAfter == nil)
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
