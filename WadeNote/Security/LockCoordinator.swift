import SwiftUI
import UIKit

/// 잠금 화면을 **별도 UIWindow**로 앱 콘텐츠 위에 띄운다.
/// 이렇게 하면 밑의 작업 화면(네비게이션·시트·입력 중인 텍스트)이 전혀 헐리지 않아
/// 잠금 해제 후 정확히 같은 자리에서 이어서 작업할 수 있다. 동시에 잠금 윈도우가
/// 시트보다도 위에 있어 잠금 중 민감 내용이 노출되지 않는다.
@MainActor @Observable final class LockCoordinator {
    let lock: AppLock
    private var window: UIWindow?

    init(lock: AppLock = AppLock()) {
        self.lock = lock
    }

    var isLocked: Bool { lock.isLocked }

    /// 잠금 상태로 전환하고 잠금 윈도우를 띄운다(백그라운드 진입 시).
    func engageLock() {
        lock.lock()
        showWindow()
    }

    /// 잠금 윈도우가 없으면 띄운다(잠금 상태일 때만).
    func showWindow() {
        guard lock.isLocked, window == nil, let scene = activeScene() else { return }
        let host = UIHostingController(
            rootView: LockView { [weak self] in await self?.authenticate() }
        )
        host.view.backgroundColor = .clear
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.rootViewController = host
        w.makeKeyAndVisible()
        window = w
    }

    /// Face ID(실패 시 기기 패스코드)로 인증. 성공하면 잠금 윈도우를 내린다.
    func authenticate() async {
        await lock.unlock()
        if !lock.isLocked {
            window?.isHidden = true
            window = nil
        }
    }

    /// 포그라운드 복귀 시 잠겨 있으면 인증을 시도한다.
    func authenticateIfLocked() async {
        guard lock.isLocked else { return }
        showWindow()
        await authenticate()
    }

    private func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
