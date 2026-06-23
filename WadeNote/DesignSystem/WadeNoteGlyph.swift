import SwiftUI

/// 앱 아이콘과 동일한 글리프: 흰 노트 페이지 + 가려진 •••• 점 + 블루 잠금 뱃지.
/// 앱 아이콘 SVG(viewBox 0 0 24 24) 좌표를 그대로 벡터로 렌더한다.
struct WadeNoteGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 24

            func rrect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s),
                     cornerRadius: r * s)
            }
            func dot(_ cx: Double, _ cy: Double, _ r: Double) -> Path {
                Path(ellipseIn: CGRect(x: (cx - r) * s, y: (cy - r) * s,
                                       width: 2 * r * s, height: 2 * r * s))
            }

            // 노트 본체
            ctx.fill(rrect(4.6, 3.3, 14.8, 17.4, 3.3), with: .color(.white))
            // 제목 줄
            ctx.fill(rrect(7.2, 6.9, 7, 1.7, 0.85), with: .color(Color(hex: "1c1c22")))
            // 블루 줄
            ctx.fill(rrect(7.2, 10.6, 9, 1.5, 0.75), with: .color(Color(hex: "3D74FF")))
            // 가려진 점 3개
            for cx in [7.9, 10.1, 12.3] {
                ctx.fill(dot(cx, 14.7, 0.9), with: .color(Color(hex: "c4c4ce")))
            }
            // 잠금 뱃지
            ctx.fill(rrect(12.6, 12.8, 8.4, 8.4, 2.7), with: .color(Color(hex: "3D74FF")))
            // 잠금 몸통
            ctx.fill(rrect(14.75, 16.75, 4.1, 3.05, 0.7), with: .color(.white))
            // 잠금 고리 (∩ 형태) — 앱 아이콘과 동일한 비율로 몸통에 연결.
            let sx0 = 15.55, sx1 = 18.05, spring = 15.85, bodyTop = 16.75
            let cx = (sx0 + sx1) / 2, r = (sx1 - sx0) / 2
            var shackle = Path()
            shackle.move(to: CGPoint(x: sx0 * s, y: bodyTop * s))
            shackle.addLine(to: CGPoint(x: sx0 * s, y: spring * s))
            shackle.addArc(center: CGPoint(x: cx * s, y: spring * s),
                           radius: r * s,
                           startAngle: .degrees(180), endAngle: .degrees(360),
                           clockwise: false)
            shackle.addLine(to: CGPoint(x: sx1 * s, y: bodyTop * s))
            ctx.stroke(shackle, with: .color(.white),
                       style: StrokeStyle(lineWidth: 0.82 * s, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
