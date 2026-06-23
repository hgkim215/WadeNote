import SwiftUI

struct LockView: View {
    let onUnlock: () async -> Void

    var body: some View {
        ZStack {
            // 따뜻한 뉴트럴 그라데이션 + 상단 블루 배경광
            LinearGradient(colors: [Color.lockBgTop, Color.lockBgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color.actionBlue.opacity(0.13), .clear],
                           center: UnitPoint(x: 0.5, y: 0.18), startRadius: 0, endRadius: 400)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                Spacer()
                VStack(spacing: 22) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "3c3c46"), Color(hex: "16161a")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 92, height: 92)
                        .overlay(WadeNoteGlyph().frame(width: 60, height: 60))
                        .shadow(color: Color.actionBlue.opacity(0.26), radius: 24, x: 0, y: 16)
                    VStack(spacing: 6) {
                        Text("WadeNote")
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                        Text("잠금됨 · 데이터 비공개")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                Spacer()
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Button { Task { await onUnlock() } } label: {
                            Image(systemName: "faceid")
                                .font(.system(size: 30))
                                .foregroundStyle(Color.actionBlue)
                                .frame(width: 60, height: 60)
                                .background(Color.actionBlue.opacity(0.1), in: Circle())
                                .overlay(Circle().strokeBorder(Color.actionBlue.opacity(0.22)))
                        }
                        .buttonStyle(.plain)
                        Text("Face ID로 잠금 해제")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.actionBlue)
                        Text("기기를 바라보면 자동으로 열려요")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    Button { Task { await onUnlock() } } label: {
                        Text("패스코드 입력")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.actionBlue)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)
                            .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardBorder))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 46)
            }
        }
        .task { await onUnlock() }
    }
}
