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

    static let appBackground = Color(hex: "f4f2ee")
    static let cardSurface = Color.white
    static let primaryText = Color(hex: "15151a")
    static let secondaryText = Color(hex: "8a8a92")
    static let actionBlue = Color(hex: "2D5BFF")
    static let favoriteStar = Color(hex: "FFB300")
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
