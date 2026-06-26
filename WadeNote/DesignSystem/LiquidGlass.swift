import SwiftUI

/// 화면 상단에 은은한 브랜드 배경광(액센트 라디얼)을 까는 배경.
/// appBackground 위에 한 겹 올린다. 과하지 않게 낮은 투명도.
struct BrandGlowBackground: ViewModifier {
    let accent: Color
    func body(content: Content) -> some View {
        content.background(
            ZStack {
                Color.appBackground
                // 부드러운 falloff: 중간 스톱을 두고 화면 밖까지 늘려 경계 띠가 안 보이게.
                RadialGradient(
                    colors: [accent.opacity(0.10), accent.opacity(0.03), .clear],
                    center: .top, startRadius: 0, endRadius: 720
                )
            }
            .ignoresSafeArea()
        )
    }
}

extension View {
    /// 상단 브랜드 배경광 + 앱 배경.
    func brandGlow(_ accent: Color = .actionBlue) -> some View {
        modifier(BrandGlowBackground(accent: accent))
    }
}

/// Liquid Glass 표면 카드. 깊이는 글래스가 제공하므로 수동 그림자를 쓰지 않는다.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 18
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
