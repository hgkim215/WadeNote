import SwiftUI
import UIKit

/// 가벼운 햅틱 피드백 (실기기 전용 — 시뮬레이터에선 무시됨).
enum Haptics {
    @MainActor static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// 탭 시 살짝 축소·반투명되며 스프링으로 돌아오는 버튼 스타일.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// 원형 아이콘 버튼 등 작은 컨트롤용 — 탭 시 더 또렷하게 축소.
    func pressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressableButtonStyle(scale: scale))
    }
}

/// 왼쪽으로 스와이프하면 뒤에서 빨간 삭제 버튼이 드러나는 행 래퍼.
struct SwipeToDelete<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @GestureState private var drag: CGFloat = 0
    private let reveal: CGFloat = 78

    private var x: CGFloat { min(0, max(-reveal, offset + drag)) }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: reveal)
                    .frame(maxHeight: .infinity)
                    .background(Color(hex: "FF3B30"))
            }
            .buttonStyle(.plain)
            .opacity(x < -2 ? 1 : 0)

            content()
                .background(Color.cardSurface)
                .offset(x: x)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .updating($drag) { value, state, _ in
                            if abs(value.translation.width) > abs(value.translation.height) {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let proposed = offset + value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                offset = proposed < -reveal / 2 ? -reveal : 0
                            }
                        }
                )
        }
        .clipped()
    }
}
