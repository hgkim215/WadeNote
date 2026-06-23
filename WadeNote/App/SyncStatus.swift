import Foundation
#if WADENOTE_CLOUDKIT
import CloudKit
#endif

/// iCloud 동기화 상태.
enum SyncStatus {
    case synced       // CloudKit 빌드 + iCloud 계정 사용 가능
    case needsLogin   // CloudKit 빌드인데 iCloud 계정 없음/사용 불가
    case localOnly    // CloudKit 비활성(이 기기에만 저장)
}

/// iCloud 계정 상태를 CloudKit 기준으로 판별하고, 계정 변경을 감지해 갱신한다.
@MainActor @Observable final class SyncStatusMonitor {
    private(set) var status: SyncStatus

    init() {
        #if WADENOTE_CLOUDKIT
        status = .synced   // 낙관적 초기값 — 곧 비동기로 실제 상태로 갱신
        observeAccountChanges()
        refresh()
        #else
        status = .localOnly
        #endif
    }

    /// 앱이 포그라운드로 돌아오거나 계정이 바뀔 때 호출.
    func refresh() {
        #if WADENOTE_CLOUDKIT
        Task { status = await Self.cloudAccountStatus() }
        #endif
    }

    #if WADENOTE_CLOUDKIT
    private func observeAccountChanges() {
        for name in [Notification.Name.CKAccountChanged, .NSUbiquityIdentityDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    /// CloudKit 계정 사용 가능 여부. iCloud Drive와 무관하게 CloudKit 기준으로 본다.
    private static func cloudAccountStatus() async -> SyncStatus {
        let container = CKContainer(identifier: WadeNoteApp.cloudKitContainerID)
        let status = try? await container.accountStatus()
        return status == .available ? .synced : .needsLogin
    }
    #endif
}
