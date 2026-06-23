import SwiftUI

/// 첨부 사진을 전체 화면으로 보여주고 핀치 줌·드래그·더블탭 확대를 지원한다.
/// 사진이 여러 장이면 좌우로 넘길 수 있다.
struct PhotoViewerView: View {
    let images: [UIImage]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss

    init(images: [UIImage], startIndex: Int) {
        self.images = images
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(images.indices, id: \.self) { i in
                    ZoomableImage(image: images[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.9), .black.opacity(0.35))
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .statusBarHidden(true)
    }
}

/// 핀치 줌(최대 5배), 확대 상태에서 드래그 이동, 더블탭 토글 줌.
private struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(steadyScale * value.magnification, 1), 5)
                    }
                    .onEnded { _ in
                        steadyScale = scale
                        if scale <= 1 { resetPosition() }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(width: steadyOffset.width + value.translation.width,
                                        height: steadyOffset.height + value.translation.height)
                    }
                    .onEnded { _ in steadyOffset = offset }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.3)) {
                    if scale > 1 {
                        scale = 1; steadyScale = 1; resetPosition()
                    } else {
                        scale = 2.5; steadyScale = 2.5
                    }
                }
            }
    }

    private func resetPosition() {
        offset = .zero
        steadyOffset = .zero
    }
}
