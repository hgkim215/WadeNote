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
/// 각 항목을 필드 종류(FieldKind)에 맞는 안내와 함께 제시해 영역별 매핑 정확도를 높인다.
func buildExtractionPrompt(text: String, type: ItemType, labels: [String]) -> String {
    let allowed = Set(labels)
    let items = Template.fields(for: type)
        .filter { allowed.contains($0.label) }
        .map { "- \"\($0.label)\": \(extractionGuidance(for: $0.kind))" }
        .joined(separator: "\n")
    return """
    아래 ‘\(type.displayName)’ 정보가 담긴 텍스트에서 각 항목의 값을 찾아 JSON 객체로만 답하세요.

    규칙:
    - 키는 아래 항목 이름을 그대로 정확히 사용하세요.
    - 값을 명확히 찾지 못한 항목은 생략하세요(추측하거나 지어내지 마세요).
    - 값은 원문 문자를 그대로 옮기세요. 특히 비밀번호·키·토큰은 대소문자·기호·공백을 바꾸지 마세요.
    - 날짜 값은 yyyy-MM-dd 형식으로 변환하세요.
    - 설명·코드펜스 없이 JSON 객체만 출력하세요.

    항목:
    \(items)

    텍스트:
    \(text)
    """
}

/// 필드 종류별로 모델에게 줄 매핑 힌트.
private func extractionGuidance(for kind: FieldKind) -> String {
    switch kind {
    case .text: "서비스명·이름 등 일반 텍스트 값"
    case .email: "이메일 주소 또는 로그인 아이디"
    case .secret: "비밀번호·비밀키 등 비밀값 (원문 문자 그대로)"
    case .secretNumber: "카드번호·CVC·PIN 등 숫자로 된 비밀값 (숫자만, 원문 그대로)"
    case .number: "유효기간 등 숫자 값"
    case .url: "웹 주소 (http/https 로 시작하는 링크)"
    case .date: "날짜 (yyyy-MM-dd 형식으로 변환)"
    case .multiline: "본문 전체 (여러 줄 텍스트)"
    }
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
