# 스마트 캡처 v3 비주얼 — 설계 문서 (사이클 B)

작성일: 2026-06-26
참고 디자인: WadeNote v3.dc.html (claude.ai/design 프로젝트 `679173b2-7839-4875-bf02-5f142b1ddaaa`), 신규 ② 스마트 캡처 플로우

## 목표

이미 동작하는 스마트 캡처(유형 안에서 캡처 → 온디바이스 OCR + Foundation Models →
필드 자동 채움)의 **화면 비주얼만** v3 디자인 + Liquid Glass 언어로 교체한다.
기능·데이터·보안 로직은 그대로 둔다.

## 확정된 결정

- **구조**: 유형을 사용자가 고른 뒤 **그 유형 안에서** 캡처(현행 유지). 유형 선택 전
  글로벌 캡처·자동 유형감지는 도입하지 않는다(앞 사이클에서 의도적으로 제외).
- **인라인 3상태**: 추가 폼의 스마트 캡처 섹션이 상태에 따라 캡처 카드 → 분석 중 →
  결과로 전환(별도 풀스크린 플로우 아님 — v3 "한 장의 추가 시트" 의도).
- **분석 중 스캔 애니메이션**: 캡처 이미지를 **메모리에만** 잠깐 띄우고 그 위로 스캔
  라인. 분석 종료 즉시 폐기.

## 핵심 원칙 — 기능·보안 불변

- 기존 `runSmartCapture`·`SmartCaptureEngine`·OCR·추출 로직 변경 없음(상태/뷰만 추가).
- **완전 온디바이스 유지**: 네트워크 0, 디스크 저장 0, 로깅 0.
- 진입점 가용성 게이트(`SmartCaptureAvailability` / `makeIfAvailable()`) 그대로 — 미지원
  기기에선 섹션 미노출.

## 화면 3상태

### a. 캡처 카드
히어로 글래스 카드: 제목 "캡쳐로 한 번에 채우세요" + 소스 3개(붙여넣기 · 사진첩 ·
카메라). 기존 세 개의 plain `Label` 버튼을 카드 안의 또렷한 소스 항목으로 정리. 푸터에
"캡처를 넣으면 ‘<유형>’ 칸을 자동으로 채워요. 값은 기기에서만 처리됩니다." 유지.

### b. 분석 중
캡처 이미지를 표시하고 그 위로 **스캔 라인 애니메이션**(위→아래 반복) + "텍스트 인식
중…". 액센트 색(`type.accent`) 라인 + 옅은 글로우.

### c. 결과
"캡쳐에서 가져왔어요" 짧은 배너 + 채워진 각 칸의 "확인 필요" 배지(기존 유지) +
완료 토스트("N개 항목을 채웠어요 · 확인해 주세요" / "텍스트를 찾지 못했어요", 기존 유지).

## 컴포넌트 설계 (격리)

새 뷰 파일은 `WadeNote/SmartCapture/` 에.

### 1. `SmartCaptureCard`
캡처 카드 뷰. 소스 3개의 액션 클로저를 주입받는다.
```swift
struct SmartCaptureCard: View {
    let typeName: String
    var onPaste: () -> Void
    var photoPicker: AnyView    // 호출부가 PhotosPicker 를 주입(선택 바인딩 보유)
    var onCamera: (() -> Void)?  // 카메라 가용 시에만
}
```
(PhotosPicker 는 선택 바인딩을 호출부가 가져야 하므로 뷰로 주입한다. 카메라는 시뮬레이터
등 미가용 시 nil.)

### 2. `ScanningView`
```swift
struct ScanningView: View {
    let image: UIImage
    let accent: Color
    // image 위에 위→아래 반복 스캔 라인 + "텍스트 인식 중…"
}
```
순수 표현 뷰. 애니메이션은 `.repeatForever`.

### 3. `ItemEditView` 통합
- 새 상태: `@State private var analyzingImage: UIImage?`.
- 스마트 캡처 섹션 렌더링을 상태로 분기:
  - `analyzingImage != nil` → `ScanningView(image:accent:)`
  - else → `SmartCaptureCard(...)`
- `runSmartCapture(_ imageData:engine:)` 진입 시 `analyzingImage = UIImage(data: imageData)`,
  `defer { analyzingImage = nil }` 로 종료 즉시 폐기. (기존 `isAnalyzing` 과 함께.)
  결과 채움·`needsReview`·토스트 로직은 그대로.

## 이미지 수명 / 보안

- `analyzingImage` 는 분석하는 동안만 메모리에 존재하고 `defer` 로 즉시 nil.
- 디스크 저장·네트워크 전송·로깅 없음(기존과 동일). 사용자가 방금 고른 이미지를 분석 중
  잠깐 되비추는 것뿐.

## 테스트

- 시각 컴포넌트라 신규 단위 테스트 없음. 검증:
  - iOS 26 빌드 성공(양 아키텍처) + 기존 **33개 단위 테스트 그린**.
  - 시뮬레이터 스크린샷: 캡처 카드 / 분석 중(스캔) / 결과. (스마트 캡처는 Apple
    Intelligence 기기에서만 노출되므로, 시뮬레이터에서 진입점이 안 보이면 그 자체가
    가용성 게이트 정상 동작 — 가능 환경에서 시각 확인.)
- 기존 추출·필드 채움 동작 회귀 없음.

## 스코프 밖

- 유형 선택 전 글로벌 캡처·자동 유형감지 — 미도입(현 구조 유지).
- 기능·데이터·보안 로직 변경 — 없음(상태/뷰만 추가).
- 상세/홈/잠금 등 다른 화면 — 사이클 A에서 완료, 본 사이클 범위 밖.

## 성공 기준

- 추가 폼에서 유형 선택 후 스마트 캡처가 **캡처 카드 → (캡처 시) 스캔 애니메이션 →
  결과 "확인 필요"** 3상태로 v3·Liquid Glass 스타일로 보인다.
- 분석 중 캡처 이미지가 표시되고 스캔 라인이 움직이며, 분석 종료 즉시 사라진다(메모리 폐기).
- 네트워크·디스크·로깅 없음 유지, 가용성 게이트 유지(미지원 기기 미노출).
- iOS 26 빌드 성공, 기존 33개 테스트 그린, 추출·채움 회귀 없음.
