import SwiftUI

/// 上游仓库关联、差异检查与同步。同步操作使用 GitHub 官方 merge-upstream API，
/// 只对 GitHub 标记为 Fork 的仓库启用；普通仓库可以手动关联和比较，但不会伪装成可同步 Fork。
struct UpstreamRepositoryView: View {
    let repository: Repository

    @Environment(\.dismiss) private var dismiss
    @State private var upstreamOwner = ""
    @State private var upstreamName = ""
    @State private var upstreamBranch = "main"
    @State private var targetBranch = ""
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var showSyncConfirmation = false
    @State private var comparison: UpstreamComparison?
    @State private var showComparison = false

    private var storageKey: String { "upstream.repository.\(repository.fullName.lowercased())" }
    private var hasUpstream: Bool { !upstreamOwner.isEmpty && !upstreamName.isEmpty }
    private var canSyncFork: Bool {
        guard repository.是Fork, let parent = repository.parent else { return false }
        return parent.ownerName.caseInsensitiveCompare(upstreamOwner) == .orderedSame && parent.name.caseInsensitiveCompare(upstreamName) == .orderedSame
    }
    private var upstreamFullName: String { "\(upstreamOwner)/\(upstreamName)" }

    var body: some View {
        NavigationStack {
            Form {
                Section("当前仓库") {
                    LabeledContent("仓库", value: repository.fullName)
                    LabeledContent("类型", value: repository.是Fork ? "Fork" : "普通仓库")
                    LabeledContent("默认分支", value: repository.defaultBranch ?? "main")
                }

                Section("上游仓库") {
                    if repository.是Fork, let parent = repository.parent {
                        LabeledContent("GitHub 自动识别", value: "\(parent.ownerName)/\(parent.name)")
                    }
                    TextField("上游所有者", text: $upstreamOwner)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("上游仓库名", text: $upstreamName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("上游分支", text: $upstreamBranch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("保存上游关联") { saveAssociation() }
                        .disabled(!isValidRepositoryName(upstreamOwner) || !isValidRepositoryName(upstreamName) || upstreamBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasUpstream {
                        Link("在 GitHub 打开上游", destination: URL(string: "https://github.com/\(upstreamFullName)")!)
                        Button("复制上游链接") {
                            UIPasteboard.general.string = "https://github.com/\(upstreamFullName)"
                            statusMessage = "已复制上游仓库链接"
                        }
                    }
                }

                Section("比较与同步") {
                    TextField("目标分支（当前仓库）", text: $targetBranch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        compareBranches()
                    } label: {
                        Label("检查上游差异", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(isWorking || !hasUpstream || targetBranch.isEmpty || upstreamBranch.isEmpty)

                    if canSyncFork {
                        Button(role: .destructive) {
                            showSyncConfirmation = true
                        } label: {
                            Label("同步并合并上游", systemImage: "arrow.triangle.merge")
                        }
                        .disabled(isWorking || !hasUpstream || targetBranch.isEmpty)
                    } else {
                        Text("当前仓库不是 GitHub Fork。手动关联和差异比较可用；GitHub 的 Fork 同步 API 不适用于此仓库。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if isWorking { ProgressView("正在请求 GitHub…") }
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("上游仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: loadAssociation)
            .confirmationDialog("确认同步上游代码？", isPresented: $showSyncConfirmation, titleVisibility: .visible) {
                Button("同步到 \(targetBranch)", role: .destructive) { syncUpstream() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("GitHub 将把上游分支「\(upstreamBranch)」合并到当前仓库的「\(targetBranch)」。此操作会修改远端分支；建议先检查差异并确认已有备份。上方手动填写的上游分支仅用于差异比较。")
            }
            .sheet(isPresented: $showComparison) {
                NavigationStack {
                    List {
                        if let comparison {
                            LabeledContent("上游", value: upstreamFullName + "/" + upstreamBranch)
                            LabeledContent("目标", value: repository.fullName + "/" + targetBranch)
                            LabeledContent("状态", value: comparison.status)
                            LabeledContent("领先提交", value: "\(comparison.aheadBy)")
                            LabeledContent("落后提交", value: "\(comparison.behindBy)")
                            LabeledContent("提交数量", value: "\(comparison.totalCommits)")
                            LabeledContent("变更文件", value: "\(comparison.files.count)")
                            if let url = URL(string: "https://github.com/\(upstreamFullName)/compare/\(upstreamBranch)...\(repository.ownerName):\(targetBranch)") {
                                Link("在 GitHub 查看完整比较", destination: url)
                            }
                        }
                    }
                    .navigationTitle("上游差异")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showComparison = false } } }
                }
            }
        }
    }

    private func loadAssociation() {
        if repository.是Fork, let parent = repository.parent {
            upstreamOwner = parent.ownerName
            upstreamName = parent.name
        }
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let data = saved.data(using: .utf8),
           let value = try? JSONDecoder().decode(SavedUpstream.self, from: data) {
            upstreamOwner = value.owner
            upstreamName = value.name
            upstreamBranch = value.branch
        }
        targetBranch = repository.defaultBranch ?? "main"
    }

    private func saveAssociation() {
        let value = SavedUpstream(owner: upstreamOwner.trimmingCharacters(in: .whitespacesAndNewlines),
                                  name: upstreamName.trimmingCharacters(in: .whitespacesAndNewlines),
                                  branch: upstreamBranch.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            statusMessage = "保存关联失败"
            return
        }
        UserDefaults.standard.set(encoded, forKey: storageKey)
        upstreamOwner = value.owner
        upstreamName = value.name
        upstreamBranch = value.branch
        statusMessage = "上游关联已保存"
    }

    private func compareBranches() {
        guard let upstreamOwnerEncoded = upstreamOwner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let upstreamNameEncoded = upstreamName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let upstreamBranchEncoded = upstreamBranch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let targetBranchEncoded = targetBranch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.github.com/repos/\(upstreamOwnerEncoded)/\(upstreamNameEncoded)/compare/\(upstreamBranchEncoded)...\(repository.ownerName):\(targetBranchEncoded)") else {
            statusMessage = "分支名称或仓库地址无效"
            return
        }
        request(url: url, method: "GET", body: nil) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(UpstreamComparison.self, from: data)
                    comparison = response
                    showComparison = true
                    statusMessage = "差异检查完成"
                } catch {
                    statusMessage = "解析差异结果失败：\(error.localizedDescription)"
                }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
    }

    private func syncUpstream() {
        guard targetBranch == upstreamBranch else {
            statusMessage = "GitHub 原生 Fork 同步要求上游分支与当前仓库目标分支同名。请将两个分支都设为同一个名称后再同步。"
            return
        }
        guard let owner = repository.ownerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let repo = repository.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/merge-upstream"),
              let body = try? JSONSerialization.data(withJSONObject: ["branch": upstreamBranch]) else {
            statusMessage = "仓库地址或目标分支无效"
            return
        }
        request(url: url, method: "POST", body: body) { result in
            switch result {
            case .success(let data):
                if let response = try? JSONDecoder().decode(UpstreamSyncResponse.self, from: data) {
                    statusMessage = "同步请求成功，目标分支：\(response.baseBranch ?? targetBranch)，提交：\(response.mergeType ?? "已更新")"
                } else {
                    statusMessage = "GitHub 已接受同步请求。请刷新仓库确认最新状态。"
                }
            case .failure(let error):
                statusMessage = "同步失败：\(error.localizedDescription)。请检查 Token 是否有 Contents 写入权限、分支保护规则及上游分支状态。"
            }
        }
    }

    private func request(url: URL, method: String, body: Data?, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let token = TokenKeychain.shared.getToken(), !token.isEmpty else {
            statusMessage = "请先登录 GitHub 账号"
            return
        }
        isWorking = true
        statusMessage = nil
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isWorking = false
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.failure(UpstreamError.invalidResponse))
                    return
                }
                guard let data else {
                    completion(.failure(UpstreamError.http(http.statusCode, "GitHub 返回空响应")))
                    return
                }
                guard (200..<300).contains(http.statusCode) else {
                    let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "请求失败"
                    completion(.failure(UpstreamError.http(http.statusCode, message)))
                    return
                }
                completion(.success(data))
            }
        }.resume()
    }

    private func isValidRepositoryName(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && !value.contains("/") && !value.contains(" ")
    }
}

private struct SavedUpstream: Codable {
    let owner: String
    let name: String
    let branch: String
}

private struct UpstreamComparison: Decodable {
    let status: String
    let aheadBy: Int
    let behindBy: Int
    let totalCommits: Int
    let files: [UpstreamChangedFile]

    enum CodingKeys: String, CodingKey {
        case status, files
        case aheadBy = "ahead_by"
        case behindBy = "behind_by"
        case totalCommits = "total_commits"
    }
}

private struct UpstreamChangedFile: Decodable {
    let filename: String
}

private struct UpstreamSyncResponse: Decodable {
    let baseBranch: String?
    let mergeType: String?

    enum CodingKeys: String, CodingKey {
        case baseBranch = "base_branch"
        case mergeType = "merge_type"
    }
}

private enum UpstreamError: LocalizedError {
    case invalidResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "GitHub 返回了无效响应"
        case .http(let code, let message): return "HTTP \(code)：\(message)"
        }
    }
}
