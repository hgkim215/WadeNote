import Testing
@testable import WadeNote

@Test func parsesCleanJSON() {
    let raw = #"{"아이디": "me@x.com", "비밀번호": "pw123"}"#
    let r = parseExtraction(raw, labels: ["아이디", "비밀번호", "URL"])
    #expect(r.values["아이디"] == "me@x.com")
    #expect(r.values["비밀번호"] == "pw123")
    #expect(r.values["URL"] == nil)
}

@Test func parsesJSONWithSurroundingProseAndFences() {
    let raw = "다음은 결과입니다:\n```json\n{\"아이디\": \"a@b.com\"}\n```\n참고하세요."
    let r = parseExtraction(raw, labels: ["아이디"])
    #expect(r.values["아이디"] == "a@b.com")
}

@Test func dropsUnknownLabelsAndEmptyValues() {
    let raw = #"{"아이디": "x", "메모": "   ", "유령": "z"}"#
    let r = parseExtraction(raw, labels: ["아이디", "메모"])
    #expect(r.values["아이디"] == "x")
    #expect(r.values["메모"] == nil)   // 공백만 → 제거
    #expect(r.values["유령"] == nil)   // 라벨 목록에 없음 → 제거
}

@Test func malformedReturnsEmpty() {
    #expect(parseExtraction("그냥 텍스트, JSON 없음", labels: ["아이디"]).values.isEmpty)
    #expect(parseExtraction("{망가진 json", labels: ["아이디"]).values.isEmpty)
}

@Test func promptIncludesLabelsAndText() {
    let p = buildExtractionPrompt(text: "id: a@b.com", type: .login, labels: ["아이디", "비밀번호"])
    #expect(p.contains("아이디"))
    #expect(p.contains("비밀번호"))
    #expect(p.contains("a@b.com"))
}

@Test func promptGivesPerFieldGuidance() {
    let p = buildExtractionPrompt(text: "x", type: .login, labels: ["아이디", "비밀번호", "URL"])
    #expect(p.contains("이메일"))   // 아이디(email) 안내
    #expect(p.contains("비밀값"))   // 비밀번호(secret) 안내
    #expect(p.contains("웹 주소"))  // URL 안내
}

@Test func promptInstructsDateFormat() {
    let labels = Template.fields(for: .apiKey).map(\.label)   // 발급일·만료일(date) 포함
    let p = buildExtractionPrompt(text: "발급 2024-01-02", type: .apiKey, labels: labels)
    #expect(p.contains("yyyy-MM-dd"))
}

@Test func promptIncludesTypeName() {
    let p = buildExtractionPrompt(text: "x", type: .card, labels: ["번호"])
    #expect(p.contains("카드·은행"))   // type.displayName 으로 맥락 제공
}
