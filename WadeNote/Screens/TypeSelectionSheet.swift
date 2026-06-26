import SwiftUI

/// ＋ 추가 진입 시트 — 유형을 먼저 고르고 해당 유형 입력 화면으로 넘어간다.
struct TypeSelectionSheet: View {
    var onSelect: (ItemType) -> Void

    @State private var contentHeight: CGFloat = 0
    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("새 항목 추가")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                Text("어떤 유형으로 추가할까요? 고르면 입력 화면으로 넘어가요")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // 2×2 그리드(로그인·카드·신분증·API 키) + 메모 전체 너비
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach([ItemType.login, .card, .identity, .apiKey]) { tile($0) }
            }
            tile(.memo)

            // 푸터 안내
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                Text("유형을 고르면 바로 입력 화면으로 — 상단의 스캔으로 채우기로 한 번에 채우거나 직접 입력하면 돼요")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .brandGlow()
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.visible)
    }

    private func tile(_ type: ItemType) -> some View {
        Button { onSelect(type) } label: {
            HStack(spacing: 12) {
                TypeTile(type: type, size: 38)
                Text(type.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
