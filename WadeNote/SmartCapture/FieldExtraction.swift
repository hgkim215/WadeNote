import Foundation

/// 라벨 → 추출값. 값이 비어있는 라벨은 포함하지 않는다.
struct ExtractionResult: Sendable {
    let values: [String: String]
}

/// OCR 텍스트에서 선택된 유형의 필드값을 뽑아내는 추출기.
protocol FieldExtractor: Sendable {
    func extract(from text: String, type: ItemType, labels: [String]) async throws -> ExtractionResult
}

/// 모델에 보낼 프롬프트. 유형 분류는 시키지 않고, 주어진 라벨의 값만 JSON 으로 받는다.
func buildExtractionPrompt(text: String, type: ItemType, labels: [String]) -> String {
    let labelList = labels.map { "\"\($0)\"" }.joined(separator: ", ")
    return """
    아래 텍스트에서 다음 라벨에 해당하는 값을 찾아 JSON 객체로만 답하세요.
    키는 라벨을 정확히 그대로 쓰고, 값을 찾지 못한 라벨은 생략하세요.
    설명·코드펜스 없이 JSON 객체만 출력하세요.
    라벨: [\(labelList)]

    텍스트:
    \(text)
    """
}

/// 모델 출력 문자열에서 JSON 객체를 추출해 라벨별 값으로 파싱한다.
/// 모델이 앞뒤에 설명/코드펜스를 붙여도 첫 '{' ~ 마지막 '}' 구간만 본다.
func parseExtraction(_ raw: String, labels: [String]) -> ExtractionResult {
    guard let start = raw.firstIndex(of: "{"),
          let end = raw.lastIndex(of: "}"),
          start < end else {
        return ExtractionResult(values: [:])
    }
    let json = String(raw[start...end])
    guard let data = json.data(using: .utf8),
          let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
        return ExtractionResult(values: [:])
    }
    let allowed = Set(labels)
    var values: [String: String] = [:]
    for (key, value) in decoded where allowed.contains(key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { values[key] = trimmed }
    }
    return ExtractionResult(values: values)
}
