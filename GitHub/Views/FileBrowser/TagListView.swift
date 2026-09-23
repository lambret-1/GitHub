//
//  TagListView.swift
//  GitHub
//
//  用途：仓库标签列表选择页
//  功能：展示仓库所有 Git 标签，支持搜索、选中切换到该标签版本、下载标签源代码ZIP
//  布局：独立全屏页，顶部搜索框 + 标签列表 + 下载进度浮层 + 完成/失败弹窗
//

import SwiftUI

// MARK: - 标签ZIP下载代理（独立于FileBrowserView，专用于TagListView）

/// 标签ZIP下载代理，处理下载进度、完成、失败回调
class 标签下载代理: NSObject, URLSessionDownloadDelegate {
    /// 进度回调（0.0 ~ 1.0）
    var 进度回调: ((Double) -> Void)?
    /// 完成回调（临时文件URL、响应）
    var 完成回调: ((URL, URLResponse?) -> Void)?
    /// 失败回调
    var 失败回调: ((Error) -> Void)?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        完成回调?(location, downloadTask.response)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let 进度 = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            进度回调?(进度)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let 错误 = error {
            if (错误 as NSError).code != NSURLErrorCancelled {
                失败回调?(错误)
            }
        }
    }
}

// MARK: - 标签列表页

/// 仓库标签列表选择页（独立全屏页）
struct TagListView: View {

    // MARK: - 属性

    /// 仓库所有者
    let owner: String

    /// 仓库名称
    let repo: String

    /// 当前选中的 ref（分支名或标签名），用于判断哪个标签被选中
    @Binding var 当前选中Ref: String

    /// 选中标签后的回调
    let onTagSelected: (String) -> Void

    /// 页面关闭控制器
    @Environment(\.dismiss) private var dismiss

    /// 标签列表数据
    @State private var 标签列表: [GitTag] = []

    /// 搜索关键词
    @State private var 搜索关键词: String = ""

    /// 加载状态
    @State private var 加载中: Bool = true

    /// 错误信息
    @State private var 错误信息: String?

    // MARK: - 下载相关状态

    /// 是否正在下载
    @State private var 下载中: Bool = false

    /// 下载进度（0.0 ~ 1.0）
    @State private var 下载进度: Double = 0

    /// 下载状态消息
    @State private var 下载消息: String = ""

    /// 当前正在下载的标签名
    @State private var 当前下载标签名: String = ""

    /// 是否显示下载结果弹窗
    @State private var 显示下载结果弹窗: Bool = false

    /// 下载结果弹窗消息
    @State private var 下载结果消息: String = ""

    /// 下载结果是否成功
    @State private var 下载成功: Bool = false

    /// 下载完成后的文件URL（用于分享）
    @State private var 下载完成文件URL: URL?

    // MARK: - 过滤后的标签列表

    private var 过滤后标签: [GitTag] {
        if 搜索关键词.trimmingCharacters(in: .whitespaces).isEmpty {
            return 标签列表
        }
        return 标签列表.filter { 标签 in
            标签.name.lowercased().contains(搜索关键词.lowercased())
        }
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // 搜索框
                    搜索框
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    // 内容区
                    if 加载中 {
                        加载中视图
                    } else if let 错误 = 错误信息 {
                        错误视图(错误详情: 错误)
                    } else if 标签列表.isEmpty {
                        空态视图
                    } else {
                        标签列表视图
                    }
                }

                // 下载进度浮层
                if 下载中 {
                    下载进度浮层
                }
            }
            .navigationTitle("选择标签（共\(标签列表.count)个）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                    }
                    .disabled(下载中)
                }
            }
            .alert(isPresented: $显示下载结果弹窗) {
                Alert(
                    title: Text(下载成功 ? "下载完成" : "下载失败"),
                    message: Text(下载结果消息),
                    dismissButton: .default(Text(下载成功 ? "好的" : "知道了")) {
                        if 下载成功, let 文件URL = 下载完成文件URL {
                            打开分享面板(文件URL: 文件URL)
                        }
                    }
                )
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            加载标签列表()
        }
    }

    // MARK: - 搜索框

    private var 搜索框: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索标签...", text: $搜索关键词)
                .textFieldStyle(PlainTextFieldStyle())
            if !搜索关键词.isEmpty {
                Button(action: {
                    搜索关键词 = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - 加载中视图

    private var 加载中视图: some View {
        VStack {
            Spacer()
            ProgressView("加载标签中...")
            Spacer()
        }
    }

    // MARK: - 错误视图

    private func 错误视图(错误详情: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("加载失败")
                .font(.headline)
            Text(错误详情)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                加载中 = true
                self.错误信息 = nil
                加载标签列表()
            }) {
                Text("重试")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            Spacer()
        }
    }

    // MARK: - 空态视图

    private var 空态视图: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("该仓库暂无标签")
                .font(.headline)
                .foregroundColor(.primary)
            Text("标签用于标记发布版本，如 v1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 下载进度浮层

    private var 下载进度浮层: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)

                Text("正在下载 \(当前下载标签名)")
                    .font(.headline)
                    .foregroundColor(.primary)

                VStack(spacing: 8) {
                    ProgressView(value: 下载进度)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                    Text(下载消息)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(width: 240)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }

    // MARK: - 标签列表视图

    private var 标签列表视图: some View {
        List {
            if 过滤后标签.isEmpty {
                HStack {
                    Spacer()
                    Text("未找到匹配的标签")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(过滤后标签) { 标签 in
                    HStack(spacing: 12) {
                        // 标签选择区域（点击整行选中，使用onTapGesture避免List中多Button点击冲突）
                        HStack(spacing: 12) {
                            // 标签图标
                            Image(systemName: "tag.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            // 标签名 + commit 短码
                            VStack(alignment: .leading, spacing: 2) {
                                Text(标签.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(标签.短码)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // 选中标记
                            if 当前选中Ref == 标签.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            当前选中Ref = 标签.name
                            onTagSelected(标签.name)
                            dismiss()
                        }

                        // 下载按钮（独立Button，使用borderless样式确保在List中可点击）
                        Button(action: {
                            开始下载标签(标签名: 标签.name)
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .frame(width: 40, height: 40)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.borderless)
                        .disabled(下载中)
                        .padding(.trailing, 4)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - 加载标签列表

    private func 加载标签列表() {
        GitHubAPI.shared.getTags(owner: owner, repo: repo) { 结果 in
            DispatchQueue.main.async {
                加载中 = false
                switch 结果 {
                case .success(let 标签):
                    标签列表 = 标签
                    错误信息 = nil
                case .failure(let 错误):
                    错误信息 = 错误.localizedDescription
                }
            }
        }
    }

    // MARK: - 下载标签源代码ZIP

    private func 开始下载标签(标签名: String) {
        下载中 = true
        下载进度 = 0
        下载消息 = "正在准备下载..."
        当前下载标签名 = 标签名
        下载完成文件URL = nil

        // 使用GitHub官方zipball API
        let 编码标签名 = 标签名.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? 标签名
        let 下载地址 = "https://api.github.com/repos/\(owner)/\(repo)/zipball/\(编码标签名)"

        guard let url = URL(string: 下载地址) else {
            下载失败处理(错误消息: "下载链接无效")
            return
        }

        var 请求 = URLRequest(url: url)
        if let token = TokenKeychain.shared.getToken() {
            请求.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        请求.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        请求.setValue("GitHub-iOS-Client", forHTTPHeaderField: "User-Agent")

        let 代理 = 标签下载代理()
        代理.进度回调 = { 进度 in
            DispatchQueue.main.async {
                self.下载进度 = 进度
                self.下载消息 = "正在下载... \(Int(进度 * 100))%"
            }
        }
        代理.完成回调 = { 临时文件URL, 响应 in
            self.处理下载完成(临时文件URL: 临时文件URL, 响应: 响应, 标签名: 标签名)
        }
        代理.失败回调 = { 错误 in
            DispatchQueue.main.async {
                self.下载失败处理(错误消息: "下载失败：\(错误.localizedDescription)")
            }
        }

        let 配置 = URLSessionConfiguration.default
        let 会话 = URLSession(configuration: 配置, delegate: 代理, delegateQueue: nil)
        let 任务 = 会话.downloadTask(with: 请求)
        任务.resume()
    }

    /// 处理下载完成
    private func 处理下载完成(临时文件URL: URL, 响应: URLResponse?, 标签名: String) {
        DispatchQueue.main.async {
            // 检查HTTP状态码
            if let http响应 = 响应 as? HTTPURLResponse, !(200...299).contains(http响应.statusCode) {
                self.下载失败处理(错误消息: "下载失败：服务器返回错误 \(http响应.statusCode)")
                return
            }

            // 检查临时文件是否存在
            guard FileManager.default.fileExists(atPath: 临时文件URL.path) else {
                self.下载失败处理(错误消息: "下载失败：临时文件不存在，请重试")
                return
            }

            // 生成文件名：仓库名-标签名.zip
            let 文件名 = "\(self.repo)-\(标签名).zip"

            // 保存到"下载"文件夹
            let 下载目录 = FileDownloadManager.shared.downloadDirectoryURL()
            let 目标URL = 下载目录.appendingPathComponent(文件名)

            do {
                // 如果目标文件已存在，先删除
                if FileManager.default.fileExists(atPath: 目标URL.path) {
                    try FileManager.default.removeItem(at: 目标URL)
                }

                // 移动文件到目标位置
                try FileManager.default.moveItem(at: 临时文件URL, to: 目标URL)

                self.下载中 = false
                self.下载成功 = true
                self.下载结果消息 = "已保存到下载文件夹：\(文件名)"
                self.下载完成文件URL = 目标URL
                self.显示下载结果弹窗 = true
            } catch {
                self.下载失败处理(错误消息: "保存文件失败：\(error.localizedDescription)")
            }
        }
    }

    /// 下载失败统一处理
    private func 下载失败处理(错误消息: String) {
        下载中 = false
        下载成功 = false
        下载结果消息 = 错误消息
        下载完成文件URL = nil
        显示下载结果弹窗 = true
    }

    /// 打开iOS原生分享面板
    private func 打开分享面板(文件URL: URL) {
        let 活动控制器 = UIActivityViewController(activityItems: [文件URL], applicationActivities: nil)
        活动控制器.completionWithItemsHandler = { _, _, _, _ in
            // 分享完成后不删除文件，保存在下载文件夹中
        }

        // 找到当前窗口的根视图控制器
        if let 窗口场景 = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let 根控制器 = 窗口场景.windows.first?.rootViewController {
            // 找到最顶层的视图控制器
            var 顶层控制器 = 根控制器
            while let 弹出控制器 = 顶层控制器.presentedViewController {
                顶层控制器 = 弹出控制器
            }
            顶层控制器.present(活动控制器, animated: true)
        }
    }
}

// MARK: - 预览

struct TagListView_Previews: PreviewProvider {
    static var previews: some View {
        TagListView(
            owner: "owner",
            repo: "repo",
            当前选中Ref: .constant(""),
            onTagSelected: { _ in }
        )
    }
}
