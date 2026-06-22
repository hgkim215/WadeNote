import Testing
import Foundation
@testable import WadeNote

final class FakePasteboard: PasteboardProtocol, @unchecked Sendable {
    var string: String?
}

@MainActor @Test func copySetsValueThenClears() async throws {
    let pb = FakePasteboard()
    let clip = SecureClipboard(pasteboard: pb, clearAfter: 0.1)
    clip.copy("pw123")
    #expect(pb.string == "pw123")
    try await Task.sleep(for: .milliseconds(250))
    #expect(pb.string == nil)
}

@MainActor @Test func doesNotClearIfReplaced() async throws {
    let pb = FakePasteboard()
    let clip = SecureClipboard(pasteboard: pb, clearAfter: 0.1)
    clip.copy("pw123")
    pb.string = "사용자가복사한다른값"
    try await Task.sleep(for: .milliseconds(250))
    #expect(pb.string == "사용자가복사한다른값")
}
