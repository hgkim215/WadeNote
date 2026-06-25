import Testing
import Foundation
@testable import WadeNote

private struct FakeRecognizer: TextRecognizer {
    let text: String
    func recognizeText(in imageData: Data) async throws -> String { text }
}
private struct FakeExtractor: FieldExtractor {
    let result: ExtractionResult
    func extract(from text: String, type: ItemType, labels: [String]) async throws -> ExtractionResult { result }
}

@Test func engineFlowsOCRTextIntoExtractor() async throws {
    let engine = SmartCaptureEngine(
        recognizer: FakeRecognizer(text: "id: a@b.com\npw: secret"),
        extractor: FakeExtractor(result: ExtractionResult(values: ["아이디": "a@b.com"])))
    let r = try await engine.fill(imageData: Data([1, 2, 3]), type: .login)
    #expect(r.values["아이디"] == "a@b.com")
}

@Test func engineReturnsEmptyWhenNoText() async throws {
    let engine = SmartCaptureEngine(
        recognizer: FakeRecognizer(text: "   \n  "),
        extractor: FakeExtractor(result: ExtractionResult(values: ["아이디": "x"])))
    let r = try await engine.fill(imageData: Data(), type: .login)
    #expect(r.values.isEmpty)   // OCR 텍스트 0 → 추출기 호출 없이 빈 결과
}

@Test func applyExtractionFillsMatchingFieldsAndReportsLabels() {
    let draft = Template.makeFields(for: .login)   // 서비스명/아이디/비밀번호/URL/메모
    let filled = applyExtraction(ExtractionResult(values: ["아이디": "a@b.com", "비밀번호": "pw"]), to: draft)
    #expect(Set(filled) == ["아이디", "비밀번호"])
    #expect(draft.first { $0.label == "아이디" }?.value == "a@b.com")
    #expect(draft.first { $0.label == "비밀번호" }?.value == "pw")
    #expect(draft.first { $0.label == "URL" }?.value == "")        // 미포함 → 그대로
}
