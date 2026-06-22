import SwiftUI

struct TypeTile: View {
    let type: ItemType
    var size: CGFloat = 38

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            .fill(type.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: type.symbolName)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: type.accent.opacity(0.5), radius: 6, x: 0, y: 5)
    }
}
