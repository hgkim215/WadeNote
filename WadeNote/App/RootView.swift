import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLock()

    var body: some View {
        Group {
            if lock.isLocked {
                LockView { await lock.unlock() }
            } else {
                HomeView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lock() }
        }
        .overlay {
            // 잠금 해제 상태라도 앱 스위처 스냅샷에 데이터가 남지 않도록 가림.
            if scenePhase != .active && !lock.isLocked {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
    }
}
