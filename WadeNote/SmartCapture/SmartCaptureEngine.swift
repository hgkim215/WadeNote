import Foundation

/// 이미지 데이터에서 텍스트를 인식한다(온디바이스).
protocol TextRecognizer: Sendable {
    func recognizeText(in imageData: Data) async throws -> String
}

/// 캡처 → OCR → 구조화 추출 오케스트레이션. 인식기·추출기를 주입받아 테스트 가능.
struct SmartCaptureEngine: Sendable {
    let recognizer: any TextRecognizer
    let extractor: any FieldExtractor

    /// 이미지에서 선택 유형의 필드값을 추출한다. OCR 텍스트가 비면 추출기 호출 없이 빈 결과.
    func fill(imageData: Data, type: ItemType) async throws -> ExtractionResult {
        let text = try await recognizer.recognizeText(in: imageData)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ExtractionResult(values: [:])
        }
        let labels = Template.fields(for: type).map(\.label)
        return try await extractor.extract(from: text, type: type, labels: labels)
    }
}

/// 추출 결과를 draft 필드에 채우고, 값이 채워진 필드의 라벨 목록을 돌려준다.
/// (Field 는 참조 타입이라 in-place 로 값이 갱신된다.)
@discardableResult
func applyExtraction(_ result: ExtractionResult, to draft: [Field]) -> [String] {
    var filled: [String] = []
    for field in draft {
        if let value = result.values[field.label],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            field.value = value
            filled.append(field.label)
        }
    }
    return filled
}
