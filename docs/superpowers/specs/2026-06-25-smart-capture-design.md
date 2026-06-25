# 스마트 캡처 입력 — 설계 문서

작성일: 2026-06-25
참고 디자인: WadeNote v3.dc.html (claude.ai/design 프로젝트 `679173b2-7839-4875-bf02-5f142b1ddaaa`), 신규 ② "스마트 캡처 입력" 플로우

## 목표

비밀번호·로그인 정보가 담긴 **화면 캡처(스크린샷)** 를 넣으면, 온디바이스에서 텍스트를
인식하고 **사용자가 선택한 유형의 템플릿 필드를 자동으로 채워주는** 입력 보조 기능.
사용자는 채워진 값을 확인·수정한 뒤 저장한다.

## 핵심 원칙 — 완전 온디바이스

이 앱의 약속("외부 서버로 전송하지 않습니다, 추적 없음")을 그대로 유지한다.
**네트워크 전송이 전혀 없다.** 모든 처리는 기기 안에서 끝난다.

- OCR: Apple **Vision** (온디바이스, 전 기기).
- 구조화: Apple **Foundation Models** (온디바이스 LLM). 지원 기기에서만.
- Foundation Models 미지원 기기에서는 이 기능을 **노출하지 않는다**(기존 수동 입력 유지).

## 아키텍처

```
캡처 이미지 → Vision OCR (온디바이스, 전 기기) → 텍스트
   → Foundation Models 가용?
        ├─ 예 (iOS 26 + Apple Intelligence): 선택한 유형의 필드 채움
        │     → "확인 필요" 상태로 폼에 표시 → 사용자 확인·수정 → 저장
        └─ 아니오: 진입점 자체를 숨김 → 기존 수동 입력 그대로
```

### 확정된 결정

| 항목 | 결정 |
|---|---|
| 유형 처리 | 사용자가 직접 선택. LLM은 **그 유형의 필드만** 채움. 자동 유형감지 없음. |
| 엔진 | **Foundation Models 만**. 없으면 수동(진입점 숨김). OpenAI·클라우드·프록시 없음. |
| 입력 소스 | 붙여넣기(클립보드 이미지) · 사진첩 · 카메라 |
| 캡처 이미지 | 메모리에서만 OCR 후 폐기. 디스크 저장·네트워크 전송 없음. 사용자가 원하면 항목에 첨부(기존 암호화 AttachmentStore). 기본은 폐기. |
| 미지원 기기 진입점 | **숨김**(잔소리·비활성 버튼 없음) |
| 검토 | 채워진 값마다 "확인 필요" 배지. 사용자가 확인·수정 후 "확인하고 저장". |

## 화면 흐름 (v3 디자인 그대로, 자동 유형감지 카피만 제외)

1. **추가 시트** — 유형 선택 + 캡처 영역. 입력: **붙여넣기 / 사진첩 / 카메라**.
   - FM 지원 기기에서만 캡처 영역(스마트 캡처 진입점)이 보인다.
2. **분석 중** — "캡쳐 분석 중… · 텍스트 인식", "N개 항목 발견" 진행 표시.
3. **자동 입력 결과** — 채워진 폼, 각 칸에 **"확인 필요" 배지**, 사용자가 확인·수정 →
   **"확인하고 저장"**.

## 컴포넌트 설계 (격리·테스트 가능)

새 파일은 `WadeNote/SmartCapture/` 아래에 둔다.

### 1. `TextRecognizer` (프로토콜 + Vision 구현)
이미지 → 인식 텍스트. 테스트 시 가짜 주입.
```swift
protocol TextRecognizer {
    func recognizeText(in image: UIImage) async throws -> String
}
struct VisionTextRecognizer: TextRecognizer { /* VNRecognizeTextRequest, 한국어+영어 */ }
```

### 2. `FieldExtractor` (프로토콜 + Foundation Models 구현)
OCR 텍스트 + 대상 유형의 필드 라벨 → 라벨별 값 매핑.
```swift
struct ExtractionResult {
    /// 라벨 → 추출값. 비어있는 라벨은 미포함.
    let values: [String: String]
}
protocol FieldExtractor {
    func extract(from text: String, type: ItemType, labels: [String]) async throws -> ExtractionResult
}
@available(iOS 26, *)
struct FoundationModelsExtractor: FieldExtractor { /* SystemLanguageModel 세션 + 구조화 프롬프트 */ }
```
- 프롬프트: "다음 텍스트에서 각 라벨에 해당하는 값을 찾아 JSON 으로. 없으면 생략." +
  라벨 목록 + OCR 텍스트. 유형 분류는 시키지 않는다.

### 3. `SmartCaptureAvailability`
Foundation Models 가용성 판단. 진입점 노출 여부 결정에 사용.
```swift
enum SmartCaptureAvailability {
    static var isAvailable: Bool {
        guard #available(iOS 26, *) else { return false }
        return SystemLanguageModel.default.availability == .available
    }
}
```

### 4. `SmartCaptureEngine`
오케스트레이션: 이미지 → OCR → 추출 → 결과. `TextRecognizer`·`FieldExtractor` 주입받음.
```swift
struct SmartCaptureEngine {
    let recognizer: TextRecognizer
    let extractor: FieldExtractor
    /// 이미지에서 선택 유형의 필드값을 추출한다.
    func fill(image: UIImage, type: ItemType) async throws -> ExtractionResult
}
```

### 5. 폼 통합 (`ItemEditView`)
- FM 가용 시에만 추가 시트에 "스마트 캡처로 채우기" 진입점 표시.
- 추출 결과를 draft 필드에 주입하되, 채워진 필드를 **"확인 필요"** 로 표시(신규 상태).
  - 표시 방식: 채워진 draft 필드에 임시 플래그(예: `needsReview` 로컬 상태 셋)를 두고
    배지를 그린다. 사용자가 해당 칸을 편집하면 배지 해제. 저장 시 플래그는 버린다
    (영속 모델에는 저장하지 않음).

## 에러 / 오프라인 처리

- OCR 텍스트 0개 → "텍스트를 찾지 못했어요" 안내 + 수동 입력으로.
- FM 추출 실패/비정상 응답 → "자동 채우기에 실패했어요. 직접 입력해 주세요." → 수동 폼
  유지(이미 입력한 값 보존).
- 카메라/사진첩 권한 거부 → 표준 시스템 안내, 해당 입력 소스만 비활성.
- 네트워크는 전혀 쓰지 않으므로 오프라인 고려 불필요.

## 테스트

- 단위(가짜 `TextRecognizer`/`FieldExtractor` 주입):
  - `SmartCaptureEngine.fill` 이 OCR 텍스트를 추출기로 넘기고 결과를 그대로 반환.
  - 라벨→필드 매핑: 결과의 라벨이 선택 유형의 필드에 정확히 들어가고, 미포함 라벨은
    빈 칸 유지.
  - "확인 필요" 플래그: 추출로 채워진 필드만 플래그가 서고, 사용자가 비운/직접 입력한
    필드는 안 선다.
- `SmartCaptureAvailability`: `#available` 분기는 직접 단위테스트 어려움 → 로직을
  주입 가능한 형태로 두고(가용성 Bool 주입) 진입점 노출 분기를 테스트.
- UI 흐름(추가 시트 → 분석 → 확인저장)은 시뮬레이터 수동 검증.

## 스코프 밖

- 자동 유형감지(캡처만으로 유형 판별) — 사용자가 유형을 직접 고른다.
- OpenAI·클라우드 LLM·프록시 서버·인앱 옵트인·프라이버시 문구 수정 — 온디바이스 전용이라
  전부 불필요.
- 기존 항목 편집 중 스마트 캡처 호출 — 이번엔 신규 추가 흐름에만(필요하면 다음 사이클).

## 성공 기준 (검증 방법)

- FM 지원 기기: 캡처 입력 → 분석 → 선택 유형 필드가 추출값으로 채워지고 각 칸에
  "확인 필요" 배지. 수정 후 저장 시 일반 항목과 동일하게 저장됨.
- FM 미지원 기기: 추가 시트에 스마트 캡처 진입점이 **보이지 않고**, 기존 수동 추가가
  그대로 동작.
- 캡처 이미지가 디스크/네트워크로 나가지 않음(메모리 처리 후 폐기). 첨부를 명시적으로
  고르면 기존 암호화 경로로만 저장.
- OCR/추출 실패 시 수동 입력으로 깨끗하게 폴백(입력값 보존).
- 단위 테스트 통과, 빌드 성공, 기존 기능 회귀 없음.
