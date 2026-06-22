import Testing
import CryptoKit
import Foundation
@testable import WadeNote

private func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func roundTripEncryptsAndDecrypts() throws {
    let key = SymmetricKey(size: .bits256)
    let store = AttachmentStore(directory: tempDir(), key: key)
    let plaintext = Data("신분증사진바이트".utf8)

    let id = try store.save(plaintext)
    #expect(try store.load(id: id) == plaintext)
}

@Test func storedBytesAreNotPlaintext() throws {
    let dir = tempDir()
    let key = SymmetricKey(size: .bits256)
    let store = AttachmentStore(directory: dir, key: key)
    let marker = Data("PLAINTEXT_MARKER".utf8)

    let id = try store.save(marker)
    let onDisk = try Data(contentsOf: dir.appendingPathComponent("\(id).enc"))
    #expect(!onDisk.contains(marker))
}

@Test func deleteRemovesFile() throws {
    let dir = tempDir()
    let store = AttachmentStore(directory: dir, key: SymmetricKey(size: .bits256))
    let id = try store.save(Data([1, 2, 3]))
    try store.delete(id: id)
    #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(id).enc").path))
}
