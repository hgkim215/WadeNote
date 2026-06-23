import UIKit
import UniformTypeIdentifiers

protocol PasteboardProtocol: AnyObject {
    var string: String? { get set }
    /// 비밀값을 복사하되 이 기기에만 두고(Handoff/Universal Clipboard 차단)
    /// 지정 시간 뒤 OS가 자동으로 비우도록 만료를 건다.
    func setSecureString(_ value: String, expireAfter seconds: TimeInterval)
}

extension PasteboardProtocol {
    // 기본 구현(테스트 더블 등): 단순 대입.
    func setSecureString(_ value: String, expireAfter seconds: TimeInterval) {
        string = value
    }
}

extension UIPasteboard: PasteboardProtocol {
    func setSecureString(_ value: String, expireAfter seconds: TimeInterval) {
        setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [
                .localOnly: true,                                   // 다른 기기로 동기화 금지
                .expirationDate: Date(timeIntervalSinceNow: seconds) // OS 차원 자동 만료
            ]
        )
    }
}

@MainActor final class SecureClipboard {
    private let pasteboard: PasteboardProtocol
    private let clearAfter: TimeInterval
    private var task: Task<Void, Never>?

    init(pasteboard: PasteboardProtocol = UIPasteboard.general, clearAfter: TimeInterval = 30) {
        self.pasteboard = pasteboard
        self.clearAfter = clearAfter
    }

    func copy(_ value: String) {
        pasteboard.setSecureString(value, expireAfter: clearAfter)
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
