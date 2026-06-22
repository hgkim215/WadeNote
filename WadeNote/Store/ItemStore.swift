import SwiftData
import Foundation

@MainActor final class ItemStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(type: ItemType, title: String) -> Item {
        let item = Item(title: title, type: type)
        item.fields = Template.makeFields(for: type)
        context.insert(item)
        try? context.save()
        return item
    }

    func save() throws {
        try context.save()
    }

    func delete(_ item: Item) throws {
        // 관계 deleteRule이 cascade이므로 자식 필드도 함께 삭제된다.
        context.delete(item)
        try context.save()
    }

    func toggleFavorite(_ item: Item) throws {
        item.isFavorite.toggle()
        item.updatedAt = Date()
        try context.save()
    }

    func all() throws -> [Item] {
        try context.fetch(FetchDescriptor<Item>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        ))
    }

    func favorites() throws -> [Item] {
        try all().filter(\.isFavorite)
    }

    /// 검색 대상: 제목 · 유형명 · 필드 라벨. 필드 값은 보안상 제외.
    func search(_ query: String) throws -> [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return try all() }
        return try all().filter { item in
            item.title.lowercased().contains(q)
            || item.type.displayName.lowercased().contains(q)
            || (item.fields ?? []).contains { $0.label.lowercased().contains(q) }
        }
    }
}
