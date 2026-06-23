import SwiftUI
import UIKit

extension View {
    /// 텍스트필드 바깥(아무 곳)을 탭하면 키보드를 내린다.
    /// 윈도우에 탭 제스처를 달되 `cancelsTouchesInView=false`라 버튼·다른 필드 등
    /// 기존 컨트롤 동작은 그대로 유지된다. 뷰가 사라지면 제스처를 제거한다.
    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller().allowsHitTesting(false))
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private weak var tap: UITapGestureRecognizer?

        func attach(to view: UIView) {
            // 뷰가 윈도우 계층에 붙은 다음에 제스처를 단다.
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, self.tap == nil, let window = view?.window else { return }
                let gesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
                gesture.cancelsTouchesInView = false
                gesture.delegate = self
                window.addGestureRecognizer(gesture)
                self.tap = gesture
                self.window = window
            }
        }

        func detach() {
            if let tap, let window { window.removeGestureRecognizer(tap) }
        }

        @objc private func handleTap() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }

        // 다른 제스처(스크롤·버튼 등)와 동시에 인식되도록 허용.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
