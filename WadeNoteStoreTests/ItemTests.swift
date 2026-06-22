import Testing
import SwiftData
@testable import WadeNote

@MainActor
private func makeContext() throws -> ModelContext {
    let container = try WadeNoteApp.makeContainer(inMemory: true)
    return container.mainContext
}

@MainActor @Test func itemStoresTypeAndFields() throws {
    let ctx = try makeContext()
    let item = Item(title: "Netflix", type: .login)
    item.fields = [
        Field(label: "아이디", value: "wade@email.com", kind: .text, order: 0),
        Field(label: "비밀번호", value: "pw123", kind: .secret, order: 1)
    ]
    ctx.insert(item)
    try ctx.save()

    let fetched = try ctx.fetch(FetchDescriptor<Item>())
    #expect(fetched.count == 1)
    #expect(fetched[0].type == .login)
    #expect(fetched[0].orderedFields.count == 2)
    #expect(fetched[0].orderedFields.first(where: { $0.kind == .secret })?.value == "pw123")
}

@MainActor @Test func cascadeDeletesFields() throws {
    let ctx = try makeContext()
    let item = Item(title: "X", type: .memo)
    item.fields = [Field(label: "본문", value: "secret", kind: .text, order: 0)]
    ctx.insert(item)
    try ctx.save()
    ctx.delete(item)
    try ctx.save()
    #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    #expect(try ctx.fetch(FetchDescriptor<Field>()).isEmpty)
}
