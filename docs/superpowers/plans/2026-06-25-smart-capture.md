# 스마트 캡처 입력 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 화면 캡처를 온디바이스에서 인식(Vision OCR)하고 Foundation Models 로 구조화해, 사용자가 고른 유형의 템플릿 필드를 자동으로 채워주는 입력 보조 기능을 추가한다.

**Architecture:** 완전 온디바이스(네트워크 0). 순수 함수(프롬프트 빌더·JSON 파서)와 프로토콜(`TextRecognizer`/`FieldExtractor`)로 핵심 로직을 격리해 단위 테스트하고, 실제 프레임워크 구현(Vision, FoundationModels)은 얇게 둔다. 진입점은 Foundation Models 가용 기기에서만 노출한다.

**Tech Stack:** Swift 6, SwiftUI, Vision(`VNRecognizeTextRequest`), FoundationModels(`SystemLanguageModel`/`LanguageModelSession`, iOS 26+), Swift Testing(`@Test`), xcodegen, xcodebuild.

## Global Constraints

- **완전 온디바이스. 네트워크 전송 절대 금지.** OpenAI·클라우드·프록시 없음.
- **무로깅**: OCR 텍스트·추출값·프롬프트를 `print`/`os_log`/분석에 남기지 않는다(디버그 포함).
- **무저장(휘발)**: 캡처 이미지·OCR 텍스트·LLM 세션은 메모리에서만 쓰고 폐기. 디스크 저장 없음.
- **유형 자동감지 없음**: 사용자가 유형을 고르고, 추출은 그 유형의 필드만 채운다.
- **미지원 기기**: Foundation Models 미가용 시 진입점을 **숨긴다**(잔소리·비활성 버튼 없음). 기존 수동 입력 유지.
- **Swift 6 동시성**: 액터 경계를 넘는 값은 Sendable 이어야 한다. 이미지는 `UIImage`(비-Sendable) 대신 **`Data`로 전달**한다. 추출 파이프라인 프로토콜·타입은 `Sendable` 로 표시한다. (과거 CI 빌드 실패가 정확히 이 부류의 격리 오류였다.)
- **FM API 게이트**: Foundation Models 타입은 iOS 26+ → `@available(iOS 26, *)` / `if #available(iOS 26, *)` 로 감싼다. 최소 타깃은 iOS 18.0.
- 새 소스 파일은 `WadeNote/SmartCapture/` 에 둔다. 로컬 `.xcodeproj` 는 생성물이므로, **파일 추가 후 반드시 `xcodegen generate`** 를 실행해야 빌드/테스트에 포함된다.
- 검토는 `WadeNoteTests` 단위 테스트 + 시뮬레이터/빌드. 테스트 실행(시뮬레이터 이름은 `xcrun simctl list devices available` 의 가용 iPhone 으로 대체):
  `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:WadeNoteTests -parallel-testing-enabled NO`

---

### Task 1: 추출 순수 코어 — 프롬프트 빌더 + JSON 파서

**Files:**
- Create: `WadeNote/SmartCapture/FieldExtraction.swift`
- Test: `WadeNoteTests/FieldExtractionTests.swift`

**Interfaces:**
- Consumes: 기존 `ItemType`.
- Produces:
  - `struct ExtractionResult: Sendable { let values: [String: String] }`
  - `protocol FieldExtractor: Sendable { func extract(from text: String, type: ItemType, labels: [String]) async throws -> ExtractionResult }`
  - `func buildExtractionPrompt(text: String, type: ItemType, labels: [String]) -> String`
  - `func parseExtraction(_ raw: String, labels: [String]) -> ExtractionResult`

- [ ] **Step 1: Write the failing test**

`WadeNoteTests/FieldExtractionTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate` 후 위 테스트 명령.
Expected: 컴파일 실패 — `parseExtraction`/`buildExtractionPrompt`/`ExtractionResult` 미정의.

- [ ] **Step 3: Implement**

`WadeNote/SmartCapture/FieldExtraction.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: 위 테스트 명령.
Expected: PASS (신규 5개 + 기존 전체).

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add WadeNote/SmartCapture/FieldExtraction.swift WadeNoteTests/FieldExtractionTests.swift
git commit -m "feat(smart-capture): extraction prompt builder and JSON parser"
```

---

### Task 2: 인식기 프로토콜 + 엔진 오케스트레이션 + draft 채움

**Files:**
- Create: `WadeNote/SmartCapture/SmartCaptureEngine.swift`
- Test: `WadeNoteTests/SmartCaptureEngineTests.swift`

**Interfaces:**
- Consumes: Task 1 의 `ExtractionResult`, `FieldExtractor`; 기존 `ItemType`, `Template`, `Field`.
- Produces:
  - `protocol TextRecognizer: Sendable { func recognizeText(in imageData: Data) async throws -> String }`
  - `struct SmartCaptureEngine: Sendable { let recognizer: any TextRecognizer; let extractor: any FieldExtractor; func fill(imageData: Data, type: ItemType) async throws -> ExtractionResult }`
  - `@discardableResult func applyExtraction(_ result: ExtractionResult, to draft: [Field]) -> [String]` (값이 채워진 필드의 라벨 목록 반환)

- [ ] **Step 1: Write the failing test**

`WadeNoteTests/SmartCaptureEngineTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate` 후 테스트 명령.
Expected: 컴파일 실패 — `TextRecognizer`/`SmartCaptureEngine`/`applyExtraction` 미정의.

- [ ] **Step 3: Implement**

`WadeNote/SmartCapture/SmartCaptureEngine.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: 위 테스트 명령.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add WadeNote/SmartCapture/SmartCaptureEngine.swift WadeNoteTests/SmartCaptureEngineTests.swift
git commit -m "feat(smart-capture): recognizer protocol, engine orchestration, draft fill"
```

---

### Task 3: 실제 구현 — Vision OCR + Foundation Models + 가용성/팩토리

**Files:**
- Create: `WadeNote/SmartCapture/VisionTextRecognizer.swift`
- Create: `WadeNote/SmartCapture/FoundationModelsExtractor.swift`

**Interfaces:**
- Consumes: Task 1·2 의 `TextRecognizer`, `FieldExtractor`, `SmartCaptureEngine`, `buildExtractionPrompt`, `parseExtraction`.
- Produces:
  - `struct VisionTextRecognizer: TextRecognizer`
  - `@available(iOS 26, *) struct FoundationModelsExtractor: FieldExtractor`
  - `enum SmartCaptureAvailability { static var isAvailable: Bool }`
  - `extension SmartCaptureEngine { static func makeIfAvailable() -> SmartCaptureEngine? }`

**참고:** Vision/FoundationModels 는 실제 프레임워크라 단위 테스트 불가 → 빌드로 검증. 로직은 Task 1·2 의 순수 코어에 위임해 얇게 둔다. **OCR 텍스트·모델 응답을 로그로 남기지 않는다.**

- [ ] **Step 1: Vision OCR 구현**

`WadeNote/SmartCapture/VisionTextRecognizer.swift`:

```swift
import Foundation
import Vision
import UIKit

/// Apple Vision 온디바이스 OCR. 한국어+영어, 정확도 우선.
struct VisionTextRecognizer: TextRecognizer {
    func recognizeText(in imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 2: Foundation Models 구현 + 가용성/팩토리**

`WadeNote/SmartCapture/FoundationModelsExtractor.swift`:

```swift
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
```

- [ ] **Step 3: 빌드 (CI 와 동일하게 양 아키텍처)**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
```
Expected: `** BUILD SUCCEEDED **`. (FoundationModels SDK 는 iOS 26 SDK 에 포함되어 약한 링크로 빌드됨. 사용 지점은 모두 `@available`/`if #available` 로 게이트되어 iOS 18 타깃에서도 컴파일된다.)

- [ ] **Step 4: 단위 테스트 회귀 확인**

Run: `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:WadeNoteTests -parallel-testing-enabled NO`
Expected: 기존 전체 PASS (이 태스크는 새 테스트 없음 — 빌드/회귀만).

- [ ] **Step 5: Commit**

```bash
git add WadeNote/SmartCapture/VisionTextRecognizer.swift WadeNote/SmartCapture/FoundationModelsExtractor.swift
git commit -m "feat(smart-capture): Vision OCR and Foundation Models extractor"
```

---

### Task 4: 편집 폼 통합 — 진입점(가용 시) · 붙여넣기/사진첩 · 분석 · 확인 필요 배지

**Files:**
- Modify: `WadeNote/Screens/ItemEditView.swift`

**Interfaces:**
- Consumes: Task 2·3 의 `SmartCaptureEngine`, `SmartCaptureEngine.makeIfAvailable()`, `applyExtraction`; 기존 `Template`, `Field`, `ItemType`.
- Produces: UI. 신규 단위 테스트 없음(로직은 Task 1·2 에서 검증). 카메라는 Task 5.

**설계 메모(동시성):** 캡처 이미지는 `Data` 로만 다룬다(`UIImage` 비-Sendable). 추출은 `Task { }`(MainActor 상속) 안에서 `await engine.fill(imageData:type:)` 로 수행 — 엔진·`Data`·`type` 은 모두 Sendable 이라 캡처 안전. `fill` 반환 후 MainActor 로 돌아와 `applyExtraction` 으로 draft 를 채운다.

- [ ] **Step 1: 상태 + 엔진 보유 프로퍼티 추가**

`ItemEditView` 의 `@State` 들 근처(현재 `isAttaching` 부근)에 추가:

```swift
    @State private var captureEngine = SmartCaptureEngine.makeIfAvailable()
    @State private var isAnalyzing = false
    @State private var needsReview: Set<String> = []
    @State private var photoCaptureItem: PhotosPickerItem?
    @State private var captureToast: String?
```

- [ ] **Step 2: 스마트 캡처 섹션 (생성 모드 + 가용 시에만)**

`body` 의 `Form` 안, `Section("제목")` **위**에 추가(생성 모드이고 엔진이 있을 때만 노출):

```swift
                if isCreate, let engine = captureEngine {
                    Section {
                        if isAnalyzing {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("캡쳐 분석 중…").foregroundStyle(Color.secondaryText)
                            }
                            .font(.system(size: 15))
                        } else {
                            Button {
                                if let image = UIPasteboard.general.image,
                                   let data = image.jpegData(compressionQuality: 0.9) {
                                    runSmartCapture(data, engine: engine)
                                } else {
                                    captureToast = "클립보드에 이미지가 없어요"
                                }
                            } label: {
                                Label("붙여넣기로 채우기", systemImage: "doc.on.clipboard")
                            }
                            PhotosPicker(selection: $photoCaptureItem, matching: .images) {
                                Label("사진첩에서 캡처 채우기", systemImage: "photo.on.rectangle")
                            }
                        }
                    } header: {
                        Text("스마트 캡처")
                    } footer: {
                        Text("캡처를 넣으면 ‘\(type.displayName)’ 칸을 자동으로 채워요. 값은 기기에서만 처리됩니다.")
                    }
                    .onChange(of: photoCaptureItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                runSmartCapture(data, engine: engine)
                            }
                            photoCaptureItem = nil
                        }
                    }
                }
```

- [ ] **Step 3: 추출 실행 헬퍼**

`ItemEditView` 에 메서드 추가(예: `commit()` 근처):

```swift
    /// 캡처 데이터로 추출을 돌려 draft 를 채우고, 채워진 칸을 "확인 필요"로 표시한다.
    private func runSmartCapture(_ imageData: Data, engine: SmartCaptureEngine) {
        Task {
            isAnalyzing = true
            defer { isAnalyzing = false }
            let result = (try? await engine.fill(imageData: imageData, type: type))
                ?? ExtractionResult(values: [:])
            let filled = applyExtraction(result, to: draft)
            needsReview = Set(filled)
            captureToast = filled.isEmpty ? "텍스트를 찾지 못했어요" : "\(filled.count)개 항목을 채웠어요 · 확인해 주세요"
        }
    }
```

- [ ] **Step 4: "확인 필요" 배지 + 편집 시 해제**

`fieldRow` 의 비커스텀·비날짜 분기(현재 `displayLabel(for:)` 을 쓰는 `else` 블록)의 라벨 줄에 배지를 붙이고, 값 변경 시 `needsReview` 에서 제거한다. 해당 `else` 블록을 아래로 교체:

```swift
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayLabel(for: field.wrappedValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if needsReview.contains(field.wrappedValue.label) {
                        Text("확인 필요")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "0C8E84"))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "0FA99D").opacity(0.13), in: Capsule())
                    }
                }
                inputField(field)
            }
            .onChange(of: field.wrappedValue.value) { _, _ in
                needsReview.remove(field.wrappedValue.label)
            }
        }
```

- [ ] **Step 5: 토스트 표시**

`Form` 뒤(예: `.navigationTitle` 들이 붙는 체인)에 토스트를 추가. 기존 `.toolbar { }` 뒤에 한 줄 추가:

```swift
            .overlay(alignment: .bottom) {
                if let captureToast {
                    Text(captureToast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.opacity)
                        .task(id: captureToast) {
                            try? await Task.sleep(for: .seconds(2))
                            captureToast = nil
                        }
                }
            }
```

- [ ] **Step 6: 빌드 + 시뮬레이터 확인**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
```
Expected: `** BUILD SUCCEEDED **`.

수동 확인(시뮬레이터):
- 시뮬레이터는 보통 Apple Intelligence 미지원 → `makeIfAvailable()` 이 nil → 추가 화면에 **"스마트 캡처" 섹션이 보이지 않아야** 한다(미지원 기기 동작 = 숨김 검증). 기존 수동 추가는 정상.
- (가능하면) 지원 기기/환경에서: 붙여넣기·사진첩으로 캡처 투입 → "캡쳐 분석 중…" → 해당 유형 칸이 채워지고 "확인 필요" 배지 표시 → 칸 편집 시 배지 사라짐 → 저장 정상.

- [ ] **Step 7: Commit**

```bash
git add WadeNote/Screens/ItemEditView.swift
git commit -m "feat(smart-capture): add-form entry, paste/photo sources, analyzing, review badges"
```

---

### Task 5: 카메라 입력 소스 + 권한

**Files:**
- Create: `WadeNote/SmartCapture/CameraPicker.swift`
- Modify: `WadeNote/Screens/ItemEditView.swift`
- Modify: `project.yml` (`NSCameraUsageDescription`)

**Interfaces:**
- Consumes: Task 4 의 `runSmartCapture(_:engine:)`, `captureEngine`.
- Produces: `struct CameraPicker: UIViewControllerRepresentable` (촬영 이미지를 `Data` 로 콜백).

- [ ] **Step 1: 카메라 권한 설명 추가**

`project.yml` 의 `targets.WadeNote.info.properties` 에 한 줄 추가(기존 `NSFaceIDUsageDescription` 아래):

```yaml
        NSCameraUsageDescription: "캡처를 촬영해 정보를 자동으로 채우는 데 카메라를 사용합니다."
```

- [ ] **Step 2: 카메라 피커 구현**

`WadeNote/SmartCapture/CameraPicker.swift`:

```swift
import SwiftUI
import UIKit

/// 카메라로 한 장 촬영해 JPEG `Data` 로 돌려준다.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

- [ ] **Step 3: 폼에 카메라 버튼 + 시트 연결**

`ItemEditView` 에 상태 추가(다른 `@State` 들 근처):

```swift
    @State private var showingCamera = false
```

Task 4 Step 2 의 스마트 캡처 섹션에서 `PhotosPicker { ... }` **바로 아래**(else 분기 안)에 카메라 버튼 추가:

```swift
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showingCamera = true
                                } label: {
                                    Label("카메라로 촬영해 채우기", systemImage: "camera")
                                }
                            }
```

그리고 Task 4 Step 2 섹션의 `.onChange(of: photoCaptureItem)` 뒤에 카메라 시트를 단다:

```swift
                    .sheet(isPresented: $showingCamera) {
                        CameraPicker { data in
                            if let engine = captureEngine { runSmartCapture(data, engine: engine) }
                        }
                        .ignoresSafeArea()
                    }
```

- [ ] **Step 4: 빌드 확인**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
```
Expected: `** BUILD SUCCEEDED **`. (시뮬레이터엔 카메라가 없어 버튼은 `isSourceTypeAvailable(.camera)` 로 자동 숨김 — 빌드만 확인.)

- [ ] **Step 5: Commit**

```bash
git add WadeNote/SmartCapture/CameraPicker.swift WadeNote/Screens/ItemEditView.swift project.yml WadeNote/Info.plist
git commit -m "feat(smart-capture): camera source and usage permission"
```

---

## 검증 요약 (전체 완료 후)

- `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<가용 iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO` 전체 PASS(신규 8개 포함).
- `xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED(양 아키텍처, Swift 6 격리 오류 없음).
- 시뮬레이터(미지원 환경): 추가 화면에 스마트 캡처 섹션이 숨겨지고 기존 수동 추가 정상.
- 네트워크 전송·디스크 저장·로깅이 없음(코드 리뷰로 확인): OCR 텍스트·추출값을 `print`/`os_log` 에 남기지 않음, 이미지/텍스트를 외부로 보내지 않음.
- 기존 기능(5개 유형, 필수/선택, 사진 첨부, 잠금) 회귀 없음.
