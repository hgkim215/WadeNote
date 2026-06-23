import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }

    struct RGB: Equatable { let r, g, b: Double }

    /// 테스트 헬퍼: 해석된 RGB를 1/255 단위로 반올림해 비교 가능하게 반환.
    func resolveRGB() -> RGB {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: (r * 255).rounded() / 255,
                   g: (g * 255).rounded() / 255,
                   b: (b * 255).rounded() / 255)
    }

    /// 라이트/다크에 따라 두 UIColor 중 하나를 고르는 동적 색.
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    /// hex 두 개로 만드는 적응형 색.
    static func adaptive(light: String, dark: String) -> Color {
        dynamic(light: UIColor(Color(hex: light)), dark: UIColor(Color(hex: dark)))
    }

    // 표면/텍스트 (시안 v2의 라이트/다크 토큰)
    static let appBackground  = adaptive(light: "f4f2ee", dark: "0c0c0e")
    static let cardSurface    = adaptive(light: "ffffff", dark: "17171b")
    static let primaryText    = adaptive(light: "15151a", dark: "f5f5f7")
    static let secondaryText  = adaptive(light: "8a8a92", dark: "9b9ba3")
    static let tertiaryText   = adaptive(light: "a0a0ac", dark: "76767e")
    static let actionBlue     = adaptive(light: "2D5BFF", dark: "5A86FF")
    static let favoriteStar   = Color(hex: "FFB300")

    // 헤어라인 보더·카드 그림자 (모드별 적응)
    static let cardBorder = dynamic(light: UIColor.black.withAlphaComponent(0.05),
                                    dark: UIColor.white.withAlphaComponent(0.08))
    static let cardShadow = dynamic(light: UIColor(Color(hex: "141428")).withAlphaComponent(0.10),
                                    dark: UIColor.black.withAlphaComponent(0.55))

    // 잠금 화면 배경 그라데이션 끝점
    static let lockBgTop    = adaptive(light: "fbfaf7", dark: "1b1b21")
    static let lockBgBottom = adaptive(light: "edebe5", dark: "0c0c0e")
}

extension ItemType {
    var accent: Color { Color(hex: accentHex) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: gradientHex.0), Color(hex: gradientHex.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
