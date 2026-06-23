import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator = LockCoordinator()

    var body: some View {
        // HomeView는 항상 마운트 상태 — 잠금/해제 시에도 화면·입력 상태가 보존된다.
        // 실제 잠금(Face ID)은 LockCoordinator가 별도 윈도우로 위에 띄운다.
        HomeView()
            // 앱 스위처/제어센터 등 비활성 상태에서 민감 내용이 스냅샷에 찍히지 않도록
            // 같은 윈도우의 뷰 트리 안에 불투명 가림막을 둔다. 별도 윈도우는 생성·렌더가
            // 늦어 스냅샷 타이밍을 놓치므로(내용 노출) 인-트리 오버레이로 처리한다.
            // 항상 존재시키고 불투명도만 토글해 전환 순간 렌더 지연을 없앤다.
            .overlay {
                PrivacyCover()
                    .opacity(scenePhase == .active ? 0 : 1)
                    .allowsHitTesting(scenePhase != .active)
                    .ignoresSafeArea()
                    .animation(nil, value: scenePhase)
            }
            .task {
                coordinator.showWindow()
                await coordinator.authenticate()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    coordinator.engageLock()   // 완전히 이탈할 때 잠금
                case .active:
                    Task { await coordinator.authenticateIfLocked() }
                default:
                    break
                }
            }
    }
}

/// 앱 스위처/비활성 상태에서 콘텐츠를 가리는 불투명 화면. 인증 동작 없이 가리기만 한다.
private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.lockBgTop, Color.lockBgBottom],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 18) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "3c3c46"), Color(hex: "16161a")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .overlay(WadeNoteGlyph().frame(width: 54, height: 54))
                    .shadow(color: Color.actionBlue.opacity(0.24), radius: 22, x: 0, y: 14)
                Text("WadeNote")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.primaryText)
            }
        }
    }
}
