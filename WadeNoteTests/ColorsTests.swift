import Testing
import SwiftUI
@testable import WadeNote

@MainActor @Test func hexParsesToComponents() {
    let c = Color(hex: "2D5BFF").resolveRGB()
    #expect(abs(c.r - 45.0 / 255) < 0.01)
    #expect(abs(c.g - 91.0 / 255) < 0.01)
    #expect(abs(c.b - 255.0 / 255) < 0.01)
}

@MainActor @Test func loginAccentMatchesToken() {
    #expect(ItemType.login.accent.resolveRGB() == Color(hex: "2D5BFF").resolveRGB())
}
