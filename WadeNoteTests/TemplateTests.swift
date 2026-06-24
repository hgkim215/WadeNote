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
    #expect(labels == ["서비스·용도", "API 키 · 토큰", "엔드포인트 URL", "발급일", "만료일", "메모"])
}

@Test func apiKeyMasksCombinedKeyField() {
    let specs = Template.fields(for: .apiKey)
    #expect(specs.first { $0.label == "API 키 · 토큰" }?.kind == .secret)
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

@Test func apiKeyCombinesKeyAndTokenIntoOneField() {
    let labels = Template.fields(for: .apiKey).map(\.label)
    #expect(labels == ["서비스·용도", "API 키 · 토큰", "엔드포인트 URL", "발급일", "만료일", "메모"])
    let keyField = Template.fields(for: .apiKey).first { $0.label == "API 키 · 토큰" }
    #expect(keyField?.kind == .secret)
    #expect(keyField?.required == true)
}

@Test func requiredFieldsPerType() {
    func required(_ type: ItemType) -> [String] {
        Template.fields(for: type).filter(\.required).map(\.label)
    }
    #expect(required(.login) == ["서비스명", "비밀번호"])
    #expect(required(.card) == ["카드/계좌명", "번호"])
    #expect(required(.identity) == ["종류", "번호"])
    #expect(required(.apiKey) == ["서비스·용도", "API 키 · 토큰"])
    #expect(required(.memo) == ["본문"])
}

@Test func makeFieldsCarriesRequiredFlag() {
    let fields = Template.makeFields(for: .apiKey)
    #expect(fields.first { $0.label == "서비스·용도" }?.isRequired == true)
    #expect(fields.first { $0.label == "엔드포인트 URL" }?.isRequired == false)
}

@Test func requiredFieldsSatisfiedChecksNonEmpty() {
    let fields = Template.makeFields(for: .apiKey)
    #expect(Template.requiredFieldsSatisfied(fields) == false)  // 비어있음 → 미충족
    fields.first { $0.label == "서비스·용도" }?.value = "GitHub"
    fields.first { $0.label == "API 키 · 토큰" }?.value = "ghp_xxx"
    #expect(Template.requiredFieldsSatisfied(fields) == true)
    fields.first { $0.label == "API 키 · 토큰" }?.value = "   "  // 공백만 → 미충족
    #expect(Template.requiredFieldsSatisfied(fields) == false)
}
