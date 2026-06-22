import Testing
import SwiftData
@testable import WadeNote

@MainActor
private func makeStore() throws -> ItemStore {
    let ctx = try WadeNoteApp.makeContainer(inMemory: true).mainContext
    return ItemStore(context: ctx)
}

@MainActor @Test func createUsesTemplateFields() throws {
    let store = try makeStore()
    let item = store.create(type: .login, title: "Netflix")
    #expect(item.orderedFields.map(\.label) == ["서비스명", "아이디", "비밀번호", "URL", "메모"])
    #expect(try store.all().count == 1)
}

@MainActor @Test func searchMatchesTitleAndLabelButNotValue() throws {
    let store = try makeStore()
    let item = store.create(type: .login, title: "Netflix")
    item.orderedFields.first { $0.label == "비밀번호" }?.value = "topsecret"
    try store.save()

    #expect(try store.search("netf").count == 1)
    #expect(try store.search("로그인").count == 1)
    #expect(try store.search("비밀번호").count == 1)
    #expect(try store.search("topsecret").isEmpty)
}

@MainActor @Test func toggleFavoriteAndList() throws {
    let store = try makeStore()
    let item = store.create(type: .card, title: "신한카드")
    try store.toggleFavorite(item)
    #expect(item.isFavorite)
    #expect(try store.favorites().count == 1)
    try store.toggleFavorite(item)
    #expect(try store.favorites().isEmpty)
}

@MainActor @Test func deleteRemovesItem() throws {
    let store = try makeStore()
    let item = store.create(type: .memo, title: "메모")
    try store.delete(item)
    #expect(try store.all().isEmpty)
}
