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

    /// Test-friendly factory. `inMemory` skips CloudKit entirely.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let config: ModelConfiguration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(cloudKitDatabase: .private("iCloud.com.wadenote.app"))
        return try ModelContainer(for: Item.self, configurations: config)
    }

    /// Runtime container.
    ///
    /// iCloud(CloudKit) 동기화를 켜려면 ① 프로젝트에 iCloud > CloudKit capability와
    /// `iCloud.com.wadenote.app` 컨테이너를 추가하고 개발팀 서명을 설정한 뒤
    /// ② 아래를 `try makeContainer(inMemory: false)`로 교체한다.
    /// 엔타이틀먼트 없이 CloudKit 컨테이너를 만들면 미러링이 런타임에 크래시하므로,
    /// 기본값은 로컬 저장소다.
    static func makeContainerWithFallback() -> ModelContainer {
        let local = ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        return try! ModelContainer(for: Item.self, Field.self, configurations: local)
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
