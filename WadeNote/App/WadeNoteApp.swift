import SwiftUI
import SwiftData

@main
struct WadeNoteApp: App {
    let container: ModelContainer
    @State private var clipboard = ClipboardHolder()
    @State private var attachments = AttachmentHolder()

    init() {
        container = Self.makeContainerWithFallback()
    }

    /// CloudKit private DB 컨테이너 식별자. 엔타이틀먼트의 컨테이너 ID와 일치해야 한다.
    static let cloudKitContainerID = "iCloud.com.wadenote.app"

    /// Test-friendly factory. `inMemory` skips CloudKit entirely.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let config: ModelConfiguration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(cloudKitDatabase: .private(cloudKitContainerID))
        return try ModelContainer(for: Item.self, configurations: config)
    }

    /// Runtime container.
    ///
    /// `WADENOTE_CLOUDKIT` 컴파일 플래그가 켜져 있으면 iCloud(CloudKit private DB)로
    /// 동기화한다. 이 플래그는 ① iCloud > CloudKit capability + `iCloud.com.wadenote.app`
    /// 컨테이너 + 개발팀 서명이 갖춰졌을 때만 켠다(README 참조). 엔타이틀먼트 없이
    /// CloudKit 컨테이너를 만들면 미러링이 런타임에 크래시하므로 기본값은 로컬 저장소다.
    static func makeContainerWithFallback() -> ModelContainer {
        #if WADENOTE_CLOUDKIT
        if let cloud = try? makeContainer(inMemory: false) { return cloud }
        #endif
        let local = ModelConfiguration(cloudKitDatabase: .none)
        return try! ModelContainer(for: Item.self, configurations: local)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(clipboard)
                .environment(attachments)
        }
        .modelContainer(container)
    }
}
