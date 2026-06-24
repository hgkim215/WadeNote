# "API 키 · 토큰" 유형 추가 — 설계 문서

작성일: 2026-06-24
참고 디자인: WadeNote v3.dc.html (claude.ai/design 프로젝트 `679173b2-7839-4875-bf02-5f142b1ddaaa`)

## 목표

WadeNote에 다섯 번째 보관 유형 **"API 키 · 토큰"** 을 추가한다. 데이터 모델,
유형 선택 진입, 추가/편집 폼, 상세 화면까지 한 사이클로 완성한다.

## 설계 원리

이 앱의 유형은 완전히 데이터 주도형이다. 새 유형을 추가할 때 채워야 하는 곳은
세 곳뿐이며, 나머지 화면은 자동으로 따라온다.

- 유형 선택 그리드(`ItemEditView` Picker), 추가/편집 폼, 상세 화면(`ItemDetailView`),
  홈 화면 섹션 정렬, 마스킹·복사 동작은 모두 `ItemType.allCases` + `Template` 기반으로
  자동 생성된다.

따라서 작업은 (1) 모델, (2) 필드 템플릿, (3) 시각 테마 세 곳을 채우고, (4) 빈 화면
일러스트·문구 두 곳을 손보는 것으로 끝난다.

## 1. 데이터 모델 — `WadeNote/Models/ItemType.swift`

`enum ItemType` 에 `apiKey` 케이스를 추가한다. 순서는 `identity` 와 `memo` 사이.

```swift
case login, card, identity, apiKey, memo
```

- `displayName`: `"API 키 · 토큰"`
- `FieldKind` 는 기존 종류를 그대로 사용한다. 신규 종류는 만들지 않는다.

이 순서가 유형 선택 그리드, 홈 화면 섹션 정렬, 빈 화면 부채꼴 일러스트에 그대로
반영된다. 최종 순서: `로그인 → 카드·은행 → 신분증 → API 키·토큰 → 보안 메모`.

## 2. 필드 템플릿 — `WadeNote/Templates/Template.swift`

`fields(for:)` 에 `.apiKey` 분기를 추가한다.

| 라벨 | FieldKind | 동작 |
|---|---|---|
| 서비스·용도 | `.text` | 일반 텍스트 |
| API 키 | `.secret` | •••• 가림 + 눈 토글 |
| 시크릿·토큰 | `.secret` | •••• 가림 + 눈 토글 |
| 엔드포인트 URL | `.url` | URL 키보드 |
| 발급일 | `.date` | 날짜 선택기 |
| 만료일 | `.date` | 날짜 선택기 |
| 메모 | `.text` | 일반 텍스트 |

`makeFields(for:)` 는 분기 추가 없이 기존 로직이 그대로 동작한다(`fields(for:)` 를 호출).

## 3. 시각 테마 — `WadeNote/Templates/ItemType+Theme.swift`

`accentHex` / `gradientHex` / `symbolName` 세 computed property 에 `.apiKey` 분기를
추가한다. 값은 v3 디자인 문서에서 추출했다(틸 색 + 열쇠 아이콘).

| 속성 | 값 |
|---|---|
| `accentHex` | `"0FA99D"` |
| `gradientHex` | `("2FD4C6", "0FA99D")` |
| `symbolName` | `"key.fill"` |

`accentHex` 는 기존 컨벤션(그라데이션의 어두운 쪽 끝을 accent 로 사용; 예: 카드
`gradientHex=("34D27B","13A958")`, `accentHex="1FB866"` 계열)에 맞춰 `0FA99D` 로 둔다.

## 4. 자동으로 따라오는 것 (코드 작성 불필요)

- 유형 선택 진입 — `ItemEditView` 의 `ForEach(ItemType.allCases)` Picker
- 추가/편집 폼 — `Template.makeFields(for:)` 가 생성하는 필드 행
- 상세 화면 — `ItemDetailView` 의 `orderedFields` 렌더링 (마스킹·복사 포함)
- 홈 화면 유형별 섹션 — `ItemType.allCases` 순서
- 유형 타일(`TypeTile`) — `gradient` / `symbolName` 기반

## 5. 손봐야 할 자잘한 두 곳 — `WadeNote/Screens/HomeView.swift`

빈 화면(empty state)은 유형 개수 4개를 암묵적으로 가정한 부분이 있어 일반화가 필요하다.

1. **부채꼴 일러스트** (현재 `HomeView.swift:302-306` 부근)
   타일 펼침 계산이 중앙 인덱스 `1.5`(4개 기준)를 하드코딩하고 있다. 5개가 되면 `2.0`
   이 맞으므로 `(ItemType.allCases.count - 1) / 2` 로 일반화한다.

   ```swift
   let mid = Double(ItemType.allCases.count - 1) / 2  // 4개→1.5, 5개→2.0
   // rotation/offset 계산에서 1.5 대신 mid 사용
   ```

2. **안내 문구** (현재 `HomeView.swift:315` 부근)
   `"로그인 · 카드 · 신분증 · 메모를\n안전하게 한곳에 보관하세요"` 문구에 API 키를
   포함하도록 수정한다. 다섯 항목이 한 줄에 길어지므로 줄바꿈을 자연스럽게 조정한다.
   예: `"로그인 · 카드 · 신분증 · API 키 · 메모를\n안전하게 한곳에 보관하세요"`.

## 스코프 밖 (이번 작업에서 제외)

명시적으로 범위에서 제외하며, 필요하면 별도 사이클에서 다룬다.

- **"스마트 캡쳐 입력" 플로우** — v3 문서에 신규 ② 로 포함돼 있으나 이번 요청
  (모델·진입·폼·상세)에 해당하지 않는 별개 기능이다.
- **v3 의 무거운 스타일링** — 레이어드 섀도, 브랜드 배경광, 비밀값 모노스페이스 폰트
  등은 반영하지 않는다. "현재 프로젝트 디자인 시스템 그대로 유지" 원칙에 따라 API 키
  유형만 기존 앱 스타일로 추가한다.

## 성공 기준 (검증 방법)

- `ItemType.allCases` 가 5개를 반환하고 순서가 명세와 일치한다.
- 유형 선택 화면에서 "API 키 · 토큰" 이 신분증과 보안 메모 사이에 틸 색 열쇠 타일로
  나타난다.
- 새 항목 추가 시 7개 필드(서비스·용도 / API 키 / 시크릿·토큰 / 엔드포인트 URL /
  발급일 / 만료일 / 메모)가 명세된 키보드·마스킹으로 생성된다.
- 상세 화면에서 API 키·시크릿·토큰 값이 가려지고 눈 토글·복사가 동작한다.
- 빈 화면 부채꼴 일러스트가 5개 타일을 균형 있게 펼치고, 안내 문구에 API 키가 포함된다.
- 빌드가 성공하고 기존 4개 유형의 동작에 회귀가 없다.

---

## 개정 1 (2026-06-24) — 통합 키 필드 + 필수/선택 개념

초기 구현 후 사용자 피드백으로 두 가지를 변경한다.

### A. API 키·토큰 필드 통합

"API 키"와 "시크릿·토큰" 두 개의 `.secret` 필드를 **하나의 필드**로 합친다.
사용자가 API 키 *또는* 토큰 중 가진 값을 한 곳에 입력하면 된다.

개정된 `.apiKey` 템플릿(6개 필드):

| 라벨 | FieldKind | 필수 |
|---|---|---|
| 서비스·용도 | `.text` | 필수 |
| API 키 · 토큰 | `.secret` | 필수 |
| 엔드포인트 URL | `.url` | 선택 |
| 발급일 | `.date` | 선택 |
| 만료일 | `.date` | 선택 |
| 메모 | `.text` | 선택 |

### B. 필수/선택 개념 — 전 유형 적용 + 저장 차단

필드에 필수/선택 구분을 도입한다. 사용자 결정: **모든 유형에 적용**, **빈 필수
필드면 저장 차단**, 선택 필드 라벨에 **"(선택)"** 표시.

**모델** — `Field` @Model 에 `var isRequired: Bool = false` 저장 속성을 추가한다
(`isCustom` 과 동일한 방식). `FieldSpec` 에 `required: Bool`(기본 false)을 추가하고
`Template.makeFields(for:)` 가 `f.isRequired = spec.required` 로 설정한다.

**유형별 필수 필드** — 사용자는 API 키 유형만 명시했고("서비스·용도 + API 키·토큰"),
나머지 유형은 "이름 필드 + 주요 비밀값" 을 필수로 하는 합리적 기본값을 적용한다
(사용자 검토 후 조정 가능):

| 유형 | 필수 필드 |
|---|---|
| login | 서비스명, 비밀번호 (아이디·URL·메모는 선택) |
| card | 카드/계좌명, 번호 (유효기간·CVC·비밀번호·메모는 선택) |
| identity | 종류, 번호 (발급일·만료일·메모는 선택) |
| apiKey | 서비스·용도, API 키 · 토큰 (URL·발급일·만료일·메모는 선택) |
| memo | 본문 |

**UI — 편집 폼(`ItemEditView`)**
- 비커스텀(템플릿) 필드 중 `isRequired == false` 인 필드는 라벨에 ` (선택)` 을 덧붙여
  표시한다. 커스텀 필드는 사용자가 이름을 직접 입력하고 본래 선택이므로 "(선택)" 마커를
  붙이지 않는다.
- "(선택)" 마커는 **편집 폼에서만** 표시한다. 읽기 전용 상세 화면(`FieldRow`)에는
  표시하지 않는다(입력 요건에 관한 것이므로).
- `commit()` 저장 검증: 모든 필수 필드의 값(공백 trim)이 비어있지 않아야 한다.
  하나라도 비면 툴바 "저장" 버튼을 `.disabled` 처리한다. 검증 로직은 테스트 가능한
  순수 함수 `Template.requiredFieldsSatisfied(_:)` 로 분리한다.

### 마이그레이션 / 알려진 한계

- `isRequired` 는 기본값 false 로 추가되므로 기존 SwiftData 데이터는 영향 없다
  (스키마 비파괴적). 이미 저장된 항목의 필드는 `isRequired == false` 로 로드되어
  **소급 강제되지 않는다**. 이번 개정 이후 새로 만든 항목부터 필수 검증이 적용된다.
  (앱이 막 출시된 시점이라 대부분 신규 데이터이므로 수용 가능.)
- "제목"(title) 은 필드와 별개이며 이번 필수 검증 범위에 포함하지 않는다.

### 개정 성공 기준

- `Template.fields(for: .apiKey)` 라벨이 `["서비스·용도", "API 키 · 토큰",
  "엔드포인트 URL", "발급일", "만료일", "메모"]` 이고 "API 키 · 토큰" 은 `.secret`·필수.
- 각 유형의 필수 필드가 위 표와 일치한다(`makeFields` 의 `isRequired` 검증).
- `Template.requiredFieldsSatisfied(_:)` 가 필수 필드 누락 시 false, 모두 채워지면 true.
- 편집 폼에서 선택 필드 라벨에 "(선택)" 이 보이고, 필수 필드가 비면 "저장" 버튼이
  비활성화된다.
- 빌드 성공, 기존 동작 회귀 없음.
