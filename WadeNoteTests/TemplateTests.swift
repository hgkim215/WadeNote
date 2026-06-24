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

@Test func apiKeyTemplateHasExpectedFields() {
    let labels = Template.fields(for: .apiKey).map(\.label)
    #expect(labels == ["서비스·용도", "API 키", "시크릿·토큰", "엔드포인트 URL", "발급일", "만료일", "메모"])
}

@Test func apiKeyMasksKeyAndToken() {
    let specs = Template.fields(for: .apiKey)
    #expect(specs.first { $0.label == "API 키" }?.kind == .secret)
    #expect(specs.first { $0.label == "시크릿·토큰" }?.kind == .secret)
    #expect(specs.first { $0.label == "엔드포인트 URL" }?.kind == .url)
    #expect(specs.first { $0.label == "발급일" }?.kind == .date)
}

@Test func apiKeyHasTealThemeAndKeyIcon() {
    #expect(ItemType.apiKey.accentHex == "0FA99D")
    #expect(ItemType.apiKey.gradientHex == ("2FD4C6", "0FA99D"))
    #expect(ItemType.apiKey.symbolName == "key.fill")
}

@Test func itemTypeOrderPlacesApiKeyBetweenIdentityAndMemo() {
    #expect(ItemType.allCases.map(\.rawValue) == ["login", "card", "identity", "apiKey", "memo"])
}
