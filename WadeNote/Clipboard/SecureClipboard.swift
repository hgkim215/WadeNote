import UIKit

protocol PasteboardProtocol: AnyObject {
    var string: String? { get set }
}

extension UIPasteboard: PasteboardProtocol {}

@MainActor final class SecureClipboard {
    private let pasteboard: PasteboardProtocol
    private let clearAfter: TimeInterval
    private var task: Task<Void, Never>?

    init(pasteboard: PasteboardProtocol = UIPasteboard.general, clearAfter: TimeInterval = 30) {
        self.pasteboard = pasteboard
        self.clearAfter = clearAfter
    }

    func copy(_ value: String) {
        pasteboard.string = value
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(clearAfter))
            if !Task.isCancelled, pasteboard.string == value {
                pasteboard.string = nil
            }
        }
    }

    func clearNow() {
        task?.cancel()
        pasteboard.string = nil
    }
}

/// 환경 주입용 래퍼.
@MainActor @Observable final class ClipboardHolder {
    let clipboard = SecureClipboard()
}
