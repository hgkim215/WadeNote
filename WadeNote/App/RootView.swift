import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator = LockCoordinator()

    var body: some View {
        // HomeView는 항상 마운트 상태 — 잠금/해제 시에도 화면·입력 상태가 보존된다.
        // 잠금 화면은 LockCoordinator가 별도 윈도우로 위에 띄운다.
        HomeView()
            .task {
                coordinator.showWindow()
                await coordinator.authenticate()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    coordinator.engageLock()   // 완전히 이탈할 때만 잠금(스냅샷도 가림)
                case .active:
                    Task { await coordinator.authenticateIfLocked() }
                default:
                    break
                }
            }
    }
}
