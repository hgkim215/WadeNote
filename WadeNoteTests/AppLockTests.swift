import Testing
@testable import WadeNote

struct StubAuth: BiometricAuthenticating {
    let success: Bool
    func evaluate(reason: String) async -> Bool { success }
}

@MainActor @Test func unlockSucceeds() async {
    let lock = AppLock(auth: StubAuth(success: true))
    #expect(lock.isLocked)
    await lock.unlock()
    #expect(!lock.isLocked)
}

@MainActor @Test func unlockFailsStaysLocked() async {
    let lock = AppLock(auth: StubAuth(success: false))
    await lock.unlock()
    #expect(lock.isLocked)
}

@MainActor @Test func lockReengages() async {
    let lock = AppLock(auth: StubAuth(success: true))
    await lock.unlock()
    lock.lock()
    #expect(lock.isLocked)
}
