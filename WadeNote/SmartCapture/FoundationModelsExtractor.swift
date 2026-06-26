import Foundation
import FoundationModels

/// 온디바이스 Foundation Models 로 OCR 텍스트를 라벨별 값으로 구조화한다.
/// 세션은 호출마다 새로 만들고 반환 후 해제(트랜스크립트 영속화 없음).
struct FoundationModelsExtractor: FieldExtractor {
    func extract(from text: String, type: ItemType, labels: [String]) async throws -> ExtractionResult {
        let session = LanguageModelSession()
        let prompt = buildExtractionPrompt(text: text, type: type, labels: labels)
        let response = try await session.respond(to: prompt)
        return parseExtraction(response.content, labels: labels)
    }
}

/// Foundation Models 가용 여부(진입점 노출 판단). Apple Intelligence 지원 기기에서만 true.
enum SmartCaptureAvailability {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }
}

extension SmartCaptureEngine {
    /// FM 가용 시에만 엔진을 만든다. 미지원이면 nil → 진입점 숨김.
    static func makeIfAvailable() -> SmartCaptureEngine? {
        #if targetEnvironment(simulator) && DEBUG
        // 시뮬레이터엔 Apple Intelligence 가 없어 캡처 카드를 볼 수 없으므로,
        // 디버그 시뮬레이터에서만 스텁 엔진으로 플로우를 확인할 수 있게 한다.
        return SmartCaptureEngine(recognizer: StubTextRecognizer(),
                                  extractor: StubFieldExtractor())
        #else
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        return SmartCaptureEngine(recognizer: VisionTextRecognizer(),
                                  extractor: FoundationModelsExtractor())
        #endif
    }
}

#if targetEnvironment(simulator) && DEBUG
/// 디버그 시뮬레이터 전용: 스캔 애니메이션이 보이도록 잠깐 쉬고 더미 텍스트를 돌려준다.
private struct StubTextRecognizer: TextRecognizer {
    func recognizeText(in imageData: Data) async throws -> String {
        try? await Task.sleep(for: .seconds(1.4))
        return "stub"
    }
}
/// 디버그 시뮬레이터 전용: 선택 유형의 앞쪽 라벨에 샘플 값을 채운다.
private struct StubFieldExtractor: FieldExtractor {
    func extract(from text: String, type: ItemType, labels: [String]) async throws -> ExtractionResult {
        var values: [String: String] = [:]
        for label in labels {
            switch label {
            case "서비스명", "서비스·용도", "카드/계좌명", "종류": values[label] = "GitHub"
            case "아이디": values[label] = "wade@email.com"
            case "비밀번호": values[label] = "demo-pass-123"
            case "API 키 · 토큰": values[label] = "ghp_demoToken123"
            default: break
            }
        }
        return ExtractionResult(values: values)
    }
}
#endif
