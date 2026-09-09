import SwiftUI
import UIKit
import UniformTypeIdentifiers

// ==============================================================================
// DocumentPickerView 文件选择器
// 功能：包装UIDocumentPickerViewController，支持单选/多选，选择后返回文件列表
// ==============================================================================

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void
    let onCancel: (() -> Void)?
    let allowsMultipleSelection: Bool

    init(
        allowsMultipleSelection: Bool = true,
        onPick: @escaping ([URL]) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 使用.item类型支持所有文件类型，确保可以选中任意文件
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = allowsMultipleSelection
        documentPicker.shouldShowFileExtensions = true
        documentPicker.modalPresentationStyle = .formSheet
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        let onCancel: (() -> Void)?

        init(onPick: @escaping ([URL]) -> Void, onCancel: (() -> Void)?) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !urls.isEmpty else { return }
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel?()
        }
    }
}
