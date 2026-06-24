# "API 키 · 토큰" 유형 추가 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** WadeNote에 다섯 번째 보관 유형 "API 키 · 토큰"을 추가한다 (모델 · 필드 템플릿 · 시각 테마 · 빈 화면 일러스트/문구).

**Architecture:** 이 앱의 유형은 데이터 주도형이다. `ItemType` enum 에 케이스를 추가하고 `Template`(필드 구성)과 `ItemType+Theme`(색·아이콘) 분기를 채우면 유형 선택 진입·추가/편집 폼·상세 화면·마스킹·복사가 자동으로 따라온다. 추가로 4개 유형을 가정한 빈 화면 일러스트만 5개로 일반화한다.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing (`@Test`), xcodebuild (iOS Simulator).

## Global Constraints

- 유형 순서(verbatim): `로그인 → 카드·은행 → 신분증 → API 키·토큰 → 보안 메모`. enum 선언 순서가 곧 표시 순서다 (`apiKey` 는 `identity` 와 `memo` 사이).
- 신규 `FieldKind` 를 만들지 않는다. 기존 종류(`text`/`secret`/`url`/`date`)만 사용한다.
- `displayName` 문자열(verbatim): `"API 키 · 토큰"`.
- 테마 값(verbatim): `accentHex = "0FA99D"`, `gradientHex = ("2FD4C6", "0FA99D")`, `symbolName = "key.fill"`.
- 스코프 밖: "스마트 캡쳐 입력" 플로우, v3 의 무거운 스타일링(레이어드 섀도·브랜드 배경광·비밀값 모노스페이스)은 반영하지 않는다.
- Swift switch 는 exhaustive 하므로 `case apiKey` 추가 시 `displayName`·`Template.fields(for:)`·`accentHex`·`gradientHex`·`symbolName` 5개 분기를 모두 채워야 빌드된다. Task 1 에서 한꺼번에 처리한다.
- 검증은 `WadeNoteTests` 타깃 단위 테스트 + 시뮬레이터 빌드로 한다. 테스트 실행 예시(시뮬레이터 이름은 `xcrun simctl list devices available` 로 가용한 iPhone 으로 대체):
  `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WadeNoteTests`

---

### Task 1: `apiKey` 유형 — 모델 · 필드 템플릿 · 시각 테마

**Files:**
- Modify: `WadeNote/Models/ItemType.swift` (enum 케이스 + `displayName`)
- Modify: `WadeNote/Templates/Template.swift` (`fields(for:)` 의 `.apiKey` 분기)
- Modify: `WadeNote/Templates/ItemType+Theme.swift` (`accentHex`/`gradientHex`/`symbolName` 의 `.apiKey` 분기)
- Test: `WadeNoteTests/TemplateTests.swift` (테스트 추가)

**Interfaces:**
- Consumes: 기존 `ItemType`, `FieldSpec`, `FieldKind`, `Template.fields(for:)`, `Template.makeFields(for:)`.
- Produces:
  - `ItemType.apiKey` (enum case, `id == "apiKey"`)
  - `ItemType.apiKey.displayName == "API 키 · 토큰"`
  - `Template.fields(for: .apiKey)` → 7개 `FieldSpec` (라벨 순서: `["서비스·용도", "API 키", "시크릿·토큰", "엔드포인트 URL", "발급일", "만료일", "메모"]`; "API 키"/"시크릿·토큰" 의 `kind == .secret`)
  - `ItemType.apiKey.accentHex == "0FA99D"`, `gradientHex == ("2FD4C6", "0FA99D")`, `symbolName == "key.fill"`

- [ ] **Step 1: Write the failing test**

`WadeNoteTests/TemplateTests.swift` 끝에 추가:

```swift
@Test func apiKeyTemplateHasExpectedFields() {
    let labels = Template.fields(for: .apiKey).map(\.label)
    #expect(labels == ["서비스·용도", "API 키", "시크릿·토큰", "엔드포인트 URL", "발급일", "만료일", "메모"])
}

@Test func apiKeyMasksKeyAndToken() {
    let specs = Template.fields(for: .apiKey)
    #expect(specs.first { $0.label == "API 키" }?.kind == .secret)
    #expect(specs.first { $0.label == "시크릿·토큰" }?.kind == .secret)
    #expect(specs.first { $0.label == "엔드포인트 URL" }?.kind == .url)
    #expect(specs.first { $0.label == "발급일" }?.kind == .date)
}

@Test func apiKeyHasTealThemeAndKeyIcon() {
    #expect(ItemType.apiKey.accentHex == "0FA99D")
    #expect(ItemType.apiKey.gradientHex == ("2FD4C6", "0FA99D"))
    #expect(ItemType.apiKey.symbolName == "key.fill")
}

@Test func itemTypeOrderPlacesApiKeyBetweenIdentityAndMemo() {
    #expect(ItemType.allCases.map(\.rawValue) == ["login", "card", "identity", "apiKey", "memo"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WadeNoteTests`
Expected: 컴파일 실패 — `ItemType` 에 `apiKey` 멤버가 없음 (`type 'ItemType' has no member 'apiKey'`).

- [ ] **Step 3: 모델 — `WadeNote/Models/ItemType.swift`**

`case` 선언에 `apiKey` 를 `identity` 와 `memo` 사이에 추가하고, `displayName` switch 에 분기 추가:

```swift
enum ItemType: String, Codable, CaseIterable, Identifiable {
    case login, card, identity, apiKey, memo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .login: "로그인"
        case .card: "카드·은행"
        case .identity: "신분증"
        case .apiKey: "API 키 · 토큰"
        case .memo: "보안 메모"
        }
    }
}
```

- [ ] **Step 4: 필드 템플릿 — `WadeNote/Templates/Template.swift`**

`fields(for:)` switch 의 `.identity` 와 `.memo` 분기 사이에 추가:

```swift
        case .apiKey:
            [.init(label: "서비스·용도", kind: .text),
             .init(label: "API 키", kind: .secret),
             .init(label: "시크릿·토큰", kind: .secret),
             .init(label: "엔드포인트 URL", kind: .url),
             .init(label: "발급일", kind: .date),
             .init(label: "만료일", kind: .date),
             .init(label: "메모", kind: .text)]
```

- [ ] **Step 5: 시각 테마 — `WadeNote/Templates/ItemType+Theme.swift`**

세 computed property 각각의 `.identity` 분기 뒤(`.memo` 앞)에 `.apiKey` 분기 추가:

```swift
    var accentHex: String {
        switch self {
        case .login: "2D5BFF"
        case .card: "1FB866"
        case .identity: "8741E6"
        case .apiKey: "0FA99D"
        case .memo: "7C828F"
        }
    }

    var gradientHex: (String, String) {
        switch self {
        case .login: ("4F8BFF", "2D5BFF")
        case .card: ("34D27B", "13A958")
        case .identity: ("B26BF7", "8741E6")
        case .apiKey: ("2FD4C6", "0FA99D")
        case .memo: ("AAB0BD", "7C828F")
        }
    }

    var symbolName: String {
        switch self {
        case .login: "lock.fill"
        case .card: "creditcard.fill"
        case .identity: "person.text.rectangle.fill"
        case .apiKey: "key.fill"
        case .memo: "doc.text.fill"
        }
    }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WadeNoteTests`
Expected: PASS — 신규 4개 테스트 통과, 기존 `everyTypeHasTheme`(모든 유형 테마 비어있지 않음) 포함 전체 통과.

- [ ] **Step 7: Commit**

```bash
git add WadeNote/Models/ItemType.swift WadeNote/Templates/Template.swift WadeNote/Templates/ItemType+Theme.swift WadeNoteTests/TemplateTests.swift
git commit -m "feat: add \"API 키 · 토큰\" item type (model, fields, theme)"
```

---

### Task 2: 빈 화면 일러스트·문구를 5개 유형에 맞게 일반화

**Files:**
- Modify: `WadeNote/Screens/HomeView.swift` (empty state 부채꼴 일러스트 + 안내 문구)

**Interfaces:**
- Consumes: Task 1 의 `ItemType.apiKey` (이제 `ItemType.allCases.count == 5`).
- Produces: UI 변경만. 테스트 인터페이스 없음.

**참고:** 부채꼴 일러스트는 중앙 인덱스 `1.5`(4개 기준)를 하드코딩하고 있다. 5개가 되면 `2.0` 이 맞으므로 `(allCases.count - 1) / 2` 로 일반화한다. 이 화면은 UI 라 단위 테스트 대신 시뮬레이터 실행으로 확인한다.

- [ ] **Step 1: 부채꼴 일러스트 일반화**

`WadeNote/Screens/HomeView.swift` 의 `emptyState` 안 `ZStack { ForEach(...) }` 블록(현재 302–306행 부근)을 아래로 교체. 중앙 인덱스를 `mid` 로 계산:

```swift
            ZStack {
                let mid = Double(ItemType.allCases.count - 1) / 2  // 4개→1.5, 5개→2.0
                ForEach(Array(ItemType.allCases.enumerated()), id: \.offset) { i, type in
                    TypeTile(type: type, size: 58)
                        .rotationEffect(.degrees((Double(i) - mid) * 8))
                        .offset(x: (Double(i) - mid) * 34, y: abs(Double(i) - mid) * 6)
                }
            }
```

- [ ] **Step 2: 안내 문구에 API 키 포함**

같은 파일 `emptyState` 안의 안내 문구(현재 315행 부근)를 교체:

```swift
                Text("로그인 · 카드 · 신분증 · API 키 · 메모를\n안전하게 한곳에 보관하세요")
```

- [ ] **Step 3: 빌드 + 시뮬레이터 실행으로 확인**

Run: `xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED.

수동 확인(시뮬레이터에서 앱 실행, 저장된 항목 0개 상태):
- 빈 화면 부채꼴에 타일 5개가 좌우 균형 있게 펼쳐진다 (가운데 타일이 수직, 양옆이 대칭으로 기울어짐).
- 안내 문구에 "API 키" 가 포함돼 표시된다.
- 유형 추가 화면에서 "API 키 · 토큰" 이 신분증과 보안 메모 사이에 틸 색 열쇠 타일로 보인다.
- "API 키 · 토큰" 으로 새 항목 추가 시 7개 필드가 명세 순서·키보드·마스킹으로 나타난다.
- 상세 화면에서 "API 키"/"시크릿·토큰" 값이 가려지고 눈 토글·복사가 동작한다.

- [ ] **Step 4: Commit**

```bash
git add WadeNote/Screens/HomeView.swift
git commit -m "feat: include API key type in empty-state illustration and copy"
```

---

## 검증 요약 (전체 완료 후)

- `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<가용 iPhone>' -only-testing:WadeNoteTests` 전체 PASS.
- 시뮬레이터에서 위 Task 2 Step 3 수동 확인 항목 모두 충족.
- 기존 4개 유형(로그인/카드/신분증/메모)의 폼·상세·마스킹 동작에 회귀 없음.
