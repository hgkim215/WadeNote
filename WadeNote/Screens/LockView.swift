import SwiftUI

struct LockView: View {
    let onUnlock: () async -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "3c3c46"), Color(hex: "16161a")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 92, height: 92)
                    .overlay(
                        WadeNoteGlyph()
                            .frame(width: 60, height: 60)
                    )
                    .shadow(color: Color.actionBlue.opacity(0.26), radius: 20, y: 16)
                Text("WadeNote")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                Text("잠금됨 · 데이터 비공개")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Button { Task { await onUnlock() } } label: {
                    Label("Face ID로 잠금 해제", systemImage: "faceid")
                        .font(.system(size: 16, weight: .semibold))
                }
                .tint(Color.actionBlue)
                .padding(.bottom, 40)
            }
        }
        .task { await onUnlock() }
    }
}
