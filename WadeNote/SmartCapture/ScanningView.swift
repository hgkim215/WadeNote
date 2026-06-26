import SwiftUI

/// 분석 중 화면: 캡처 이미지 위로 스캔 라인이 위→아래 반복 이동한다.
/// 이미지는 호출부가 분석 동안만 메모리로 들고 주입한다(종료 시 폐기).
struct ScanningView: View {
    let image: UIImage
    let accent: Color
    @State private var sweep = false

    var body: some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [accent.opacity(0), accent.opacity(0.9), accent.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(height: 3)
                        .shadow(color: accent.opacity(0.7), radius: 6)
                        .offset(y: sweep ? geo.size.height - 3 : 0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: sweep)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .onAppear { sweep = true }
            HStack(spacing: 8) {
                ProgressView()
                Text("텍스트 인식 중…").foregroundStyle(Color.secondaryText)
            }
            .font(.system(size: 15))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
