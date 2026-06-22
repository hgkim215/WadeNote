import LocalAuthentication

protocol BiometricAuthenticating: Sendable {
    func evaluate(reason: String) async -> Bool
}

struct LAContextAuth: BiometricAuthenticating {
    func evaluate(reason: String) async -> Bool {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return await withCheckedContinuation { cont in
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }
}

@MainActor @Observable final class AppLock {
    var isLocked = true
    private let auth: BiometricAuthenticating

    init(auth: BiometricAuthenticating = LAContextAuth()) {
        self.auth = auth
    }

    func unlock() async {
        let ok = await auth.evaluate(reason: "WadeNote 잠금 해제")
        if ok { isLocked = false }
    }

    func lock() {
        isLocked = true
    }
}
