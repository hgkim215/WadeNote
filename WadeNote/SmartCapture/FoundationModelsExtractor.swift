import Foundation
import FoundationModels

/// 온디바이스 Foundation Models 로 OCR 텍스트를 라벨별 값으로 구조화한다.
/// 세션은 호출마다 새로 만들고 반환 후 해제(트랜스크립트 영속화 없음).
@available(iOS 26, *)
struct FoundationModelsExtractor: FieldExtractor {
    func extract(from text: String, type: ItemType, labels: [String]) async throws -> ExtractionResult {
        let session = LanguageModelSession()
        let prompt = buildExtractionPrompt(text: text, type: type, labels: labels)
        let response = try await session.respond(to: prompt)
        return parseExtraction(response.content, labels: labels)
    }
}

/// Foundation Models 가용 여부(진입점 노출 판단). iOS 26 + Apple Intelligence 기기에서만 true.
enum SmartCaptureAvailability {
    static var isAvailable: Bool {
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        return false
    }
}

extension SmartCaptureEngine {
    /// FM 가용 시에만 엔진을 만든다. 미지원이면 nil → 진입점 숨김.
    static func makeIfAvailable() -> SmartCaptureEngine? {
        guard #available(iOS 26, *),
              case .available = SystemLanguageModel.default.availability else {
            return nil
        }
        return SmartCaptureEngine(recognizer: VisionTextRecognizer(),
                                  extractor: FoundationModelsExtractor())
    }
}
