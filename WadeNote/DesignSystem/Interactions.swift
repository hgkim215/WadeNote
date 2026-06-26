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
/// 손가락을 직접 따라가고(단일 상태), 속도 기반 스냅 + 경계 탄성 + 버튼 페이드로 자연스럽게.
struct SwipeToDelete<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    /// 이번 제스처가 가로 스와이프인지(세로 스크롤이면 무시). 제스처 끝나면 nil.
    @State private var horizontal: Bool?

    private let reveal: CGFloat = 78
    /// 드러난 정도 0…1 (버튼 페이드·스케일용).
    private var progress: CGFloat { min(1, max(0, -offset / reveal)) }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { offset = 0 }
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(0.7 + 0.3 * progress)
                    .frame(width: reveal)
                    .frame(maxHeight: .infinity)
                    .background(Color(hex: "FF3B30"))
            }
            .buttonStyle(.plain)
            .opacity(Double(progress))
            .allowsHitTesting(offset < -2)

            content()
                .background(Color.cardSurface)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            if horizontal == nil {
                                horizontal = abs(value.translation.width) > abs(value.translation.height)
                                startOffset = offset
                            }
                            guard horizontal == true else { return }
                            var next = startOffset + value.translation.width
                            // 경계 밖은 탄성(저항)
                            if next > 0 { next /= 3 }
                            if next < -reveal { next = -reveal + (next + reveal) / 3 }
                            offset = next
                        }
                        .onEnded { value in
                            defer { horizontal = nil }
                            guard horizontal == true else { return }
                            // 속도(플릭)까지 반영해 스냅 목표 결정
                            let predicted = startOffset + value.predictedEndTranslation.width
                            let target: CGFloat = predicted < -reveal / 2 ? -reveal : 0
                            if target != 0 && offset > -reveal + 1 { Haptics.tap() }
                            withAnimation(.spring(response: 0.33, dampingFraction: 0.8)) {
                                offset = target
                            }
                        }
                )
        }
        .clipped()
    }
}
