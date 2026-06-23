import UIKit

/// 커스텀 백버튼 때문에 시스템 백버튼을 숨겨도, 왼쪽 엣지 스와이프로 뒤로가기가
/// 계속 동작하도록 NavigationController의 인터랙티브 pop 제스처를 되살린다.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 루트가 아니라 푸시된 화면일 때만 스와이프-백 허용.
        viewControllers.count > 1
    }
}
