import Foundation

/// iCloud 동기화 상태.
enum SyncStatus {
    case synced       // CloudKit 빌드 + iCloud 계정 있음
    case needsLogin   // CloudKit 빌드인데 iCloud 미로그인
    case localOnly    // CloudKit 비활성(이 기기에만 저장)

    static var current: SyncStatus {
        #if WADENOTE_CLOUDKIT
        return FileManager.default.ubiquityIdentityToken != nil ? .synced : .needsLogin
        #else
        return .localOnly
        #endif
    }
}

/// iCloud 계정 변경(로그인/로그아웃)을 감지해 상태를 실시간 갱신한다.
@MainActor @Observable final class SyncStatusMonitor {
    private(set) var status: SyncStatus = .current

    init() {
        NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// 앱이 포그라운드로 돌아올 때 호출해 설정 변경을 반영한다.
    func refresh() { status = .current }
}
