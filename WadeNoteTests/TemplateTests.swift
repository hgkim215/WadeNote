import Testing
@testable import WadeNote

@Test func loginTemplateHasExpectedFields() {
    let labels = Template.fields(for: .login).map(\.label)
    #expect(labels == ["서비스명", "아이디", "비밀번호", "URL", "메모"])
    let pw = Template.fields(for: .login).first { $0.label == "비밀번호" }
    #expect(pw?.kind == .secret)
}

@Test func cardTemplateMarksSecrets() {
    let specs = Template.fields(for: .card)
    let cvc = specs.first { $0.label == "CVC" }
    #expect(cvc?.kind == .secretNumber)
    #expect(cvc?.kind.isMasked == true)
    #expect(specs.map(\.label).contains("유효기간"))
}

@Test func makeFieldsAssignsOrder() {
    let fields = Template.makeFields(for: .identity)
    #expect(fields.map(\.order) == Array(0..<fields.count))
}

@Test func everyTypeHasTheme() {
    for type in ItemType.allCases {
        #expect(!type.accentHex.isEmpty)
        #expect(!type.symbolName.isEmpty)
    }
    #expect(ItemType.login.accentHex == "2D5BFF")
}
