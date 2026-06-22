import CryptoKit
import Foundation

struct AttachmentStore {
    let directory: URL
    let key: SymmetricKey

    init(directory: URL, key: SymmetricKey) {
        self.directory = directory
        self.key = key
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @discardableResult
    func save(_ data: Data) throws -> String {
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw CocoaError(.coderInvalidValue)
        }
        let id = UUID().uuidString
        try combined.write(to: url(for: id), options: .completeFileProtection)
        return id
    }

    func load(id: String) throws -> Data {
        let combined = try Data(contentsOf: url(for: id))
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }

    func delete(id: String) throws {
        try FileManager.default.removeItem(at: url(for: id))
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent("\(id).enc")
    }
}
