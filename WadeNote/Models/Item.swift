import SwiftData
import Foundation

@Model final class Item {
    var title: String = ""
    var typeRaw: String = ItemType.login.rawValue
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var attachmentIDs: [String] = []

    // CloudKit 통합 요건상 to-many 관계는 옵셔널이어야 한다.
    @Relationship(deleteRule: .cascade, inverse: \Field.item)
    var fields: [Field]? = []

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .login }
        set { typeRaw = newValue.rawValue }
    }

    /// 정렬된 비옵셔널 필드 접근자.
    var orderedFields: [Field] { (fields ?? []).sorted { $0.order < $1.order } }

    init(title: String, type: ItemType) {
        self.title = title
        self.typeRaw = type.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
