import Foundation
import CryptoKit

/// 환경 주입용 래퍼. 앱 시작 시 Keychain 키를 로드/생성하고 암호화 첨부 저장소를 구성.
@MainActor @Observable final class AttachmentHolder {
    let store: AttachmentStore

    init() {
        let key = (try? KeychainKey.loadOrCreateSymmetricKey(tag: "com.wadenote.attachments.key"))
            ?? SymmetricKey(size: .bits256)
        let dir = URL.documentsDirectory.appendingPathComponent("attachments")
        store = AttachmentStore(directory: dir, key: key)
    }
}
