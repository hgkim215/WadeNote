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

### Task 3: 통합 키 필드 + 필수/선택 모델·템플릿

**Files:**
- Modify: `WadeNote/Models/Field.swift` (`isRequired` 저장 속성 추가)
- Modify: `WadeNote/Templates/Template.swift` (`FieldSpec.required`, 전 유형 필수 지정, apiKey 필드 통합, `makeFields` 에 `isRequired` 반영, `requiredFieldsSatisfied` 추가)
- Test: `WadeNoteTests/TemplateTests.swift` (테스트 추가)

**Interfaces:**
- Consumes: 기존 `Field`, `FieldSpec`, `Template.fields/makeFields`, `ItemType`.
- Produces:
  - `Field.isRequired: Bool` (저장 속성, 기본 false)
  - `FieldSpec.required: Bool` (기본 false)
  - 개정된 `Template.fields(for: .apiKey)` → 6개: `["서비스·용도", "API 키 · 토큰", "엔드포인트 URL", "발급일", "만료일", "메모"]`; "API 키 · 토큰" 은 `.secret`·required
  - 유형별 required: login=서비스명·비밀번호, card=카드/계좌명·번호, identity=종류·번호, apiKey=서비스·용도·API 키 · 토큰, memo=본문
  - `Template.requiredFieldsSatisfied(_ fields: [Field]) -> Bool`

- [ ] **Step 1: Write the failing test**

`WadeNoteTests/TemplateTests.swift` 끝에 추가:

```swift
@Test func apiKeyCombinesKeyAndTokenIntoOneField() {
    let labels = Template.fields(for: .apiKey).map(\.label)
    #expect(labels == ["서비스·용도", "API 키 · 토큰", "엔드포인트 URL", "발급일", "만료일", "메모"])
    let keyField = Template.fields(for: .apiKey).first { $0.label == "API 키 · 토큰" }
    #expect(keyField?.kind == .secret)
    #expect(keyField?.required == true)
}

@Test func requiredFieldsPerType() {
    func required(_ type: ItemType) -> [String] {
        Template.fields(for: type).filter(\.required).map(\.label)
    }
    #expect(required(.login) == ["서비스명", "비밀번호"])
    #expect(required(.card) == ["카드/계좌명", "번호"])
    #expect(required(.identity) == ["종류", "번호"])
    #expect(required(.apiKey) == ["서비스·용도", "API 키 · 토큰"])
    #expect(required(.memo) == ["본문"])
}

@Test func makeFieldsCarriesRequiredFlag() {
    let fields = Template.makeFields(for: .apiKey)
    #expect(fields.first { $0.label == "서비스·용도" }?.isRequired == true)
    #expect(fields.first { $0.label == "엔드포인트 URL" }?.isRequired == false)
}

@Test func requiredFieldsSatisfiedChecksNonEmpty() {
    let fields = Template.makeFields(for: .apiKey)
    #expect(Template.requiredFieldsSatisfied(fields) == false)  // 비어있음 → 미충족
    fields.first { $0.label == "서비스·용도" }?.value = "GitHub"
    fields.first { $0.label == "API 키 · 토큰" }?.value = "ghp_xxx"
    #expect(Template.requiredFieldsSatisfied(fields) == true)
    fields.first { $0.label == "API 키 · 토큰" }?.value = "   "  // 공백만 → 미충족
    #expect(Template.requiredFieldsSatisfied(fields) == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme WadeNote -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:WadeNoteTests -parallel-testing-enabled NO`
Expected: 컴파일 실패 — `FieldSpec` 에 `required`, `Field` 에 `isRequired`, `Template.requiredFieldsSatisfied` 없음.

또한 기존 테스트 `apiKeyTemplateHasExpectedFields` / `apiKeyMasksKeyAndToken`(Task 1 에서 추가) 은 옛 7필드 구성을 기대하므로 통합 후 깨진다. **이 두 테스트를 새 6필드 구성에 맞게 수정**한다:

```swift
@Test func apiKeyTemplateHasExpectedFields() {
    let labels = Template.fields(for: .apiKey).map(\.label)
    #expect(labels == ["서비스·용도", "API 키 · 토큰", "엔드포인트 URL", "발급일", "만료일", "메모"])
}

@Test func apiKeyMasksCombinedKeyField() {
    let specs = Template.fields(for: .apiKey)
    #expect(specs.first { $0.label == "API 키 · 토큰" }?.kind == .secret)
    #expect(specs.first { $0.label == "엔드포인트 URL" }?.kind == .url)
    #expect(specs.first { $0.label == "발급일" }?.kind == .date)
}
```
(기존 `apiKeyMasksKeyAndToken` 은 삭제하고 위 `apiKeyMasksCombinedKeyField` 로 대체.)

- [ ] **Step 3: 모델 — `WadeNote/Models/Field.swift`**

`isCustom` 아래에 `isRequired` 저장 속성을 추가(기본 false, SwiftData 비파괴):

```swift
    var isCustom: Bool = false
    var isRequired: Bool = false
```

(init 시그니처는 변경하지 않는다. `isCustom` 과 동일하게 생성 후 대입으로 설정한다.)

- [ ] **Step 4: 템플릿 — `WadeNote/Templates/Template.swift`**

`FieldSpec` 에 `required` 추가(기본 false):

```swift
struct FieldSpec {
    let label: String
    let kind: FieldKind
    var required: Bool = false
}
```

`fields(for:)` 전체를 아래로 교체(전 유형 필수 지정 + apiKey 통합):

```swift
    static func fields(for type: ItemType) -> [FieldSpec] {
        switch type {
        case .login:
            [.init(label: "서비스명", kind: .text, required: true),
             .init(label: "아이디", kind: .email),
             .init(label: "비밀번호", kind: .secret, required: true),
             .init(label: "URL", kind: .url),
             .init(label: "메모", kind: .text)]
        case .card:
            [.init(label: "카드/계좌명", kind: .text, required: true),
             .init(label: "번호", kind: .secretNumber, required: true),
             .init(label: "유효기간", kind: .number),
             .init(label: "CVC", kind: .secretNumber),
             .init(label: "비밀번호", kind: .secretNumber),
             .init(label: "메모", kind: .text)]
        case .identity:
            [.init(label: "종류", kind: .text, required: true),
             .init(label: "번호", kind: .secretNumber, required: true),
             .init(label: "발급일", kind: .date),
             .init(label: "만료일", kind: .date),
             .init(label: "메모", kind: .text)]
        case .apiKey:
            [.init(label: "서비스·용도", kind: .text, required: true),
             .init(label: "API 키 · 토큰", kind: .secret, required: true),
             .init(label: "엔드포인트 URL", kind: .url),
             .init(label: "발급일", kind: .date),
             .init(label: "만료일", kind: .date),
             .init(label: "메모", kind: .text)]
        case .memo:
            [.init(label: "본문", kind: .multiline, required: true)]
        }
    }
```

`makeFields(for:)` 가 `isRequired` 를 반영하도록 교체:

```swift
    static func makeFields(for type: ItemType) -> [Field] {
        fields(for: type).enumerated().map { index, spec in
            let field = Field(label: spec.label, value: "", kind: spec.kind, order: index)
            field.isRequired = spec.required
            return field
        }
    }
```

`Template` enum 안에 검증 헬퍼 추가:

```swift
    /// 필수 필드가 모두(공백 제외) 채워졌는지. 저장 가능 여부 판단에 사용.
    static func requiredFieldsSatisfied(_ fields: [Field]) -> Bool {
        fields.allSatisfy { field in
            !field.isRequired || !field.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme WadeNote -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:WadeNoteTests -parallel-testing-enabled NO`
Expected: PASS — 신규 4개 + 수정된 2개 포함 전체 통과.

- [ ] **Step 6: Commit**

```bash
git add WadeNote/Models/Field.swift WadeNote/Templates/Template.swift WadeNoteTests/TemplateTests.swift
git commit -m "feat: merge API key/token field and add required/optional field model"
```

---

### Task 4: 편집 폼 — (선택) 라벨 + 필수 미입력 시 저장 차단

**Files:**
- Modify: `WadeNote/Screens/ItemEditView.swift`

**Interfaces:**
- Consumes: Task 3 의 `Field.isRequired`, `Template.requiredFieldsSatisfied(_:)`.
- Produces: UI 변경만. 테스트 인터페이스 없음(검증 로직은 Task 3 에서 단위 테스트됨).

**참고:** 이 화면은 SwiftUI Form 이라 단위 테스트 대신 빌드 + 시뮬레이터로 확인한다.

- [ ] **Step 1: 선택 필드 라벨 헬퍼 추가**

`ItemEditView` 안(예: `fieldRow` 위)에 라벨 표시 헬퍼를 추가:

```swift
    /// 비커스텀 선택 필드는 라벨에 " (선택)" 을 덧붙여 보여준다.
    private func displayLabel(for field: Field) -> String {
        (!field.isCustom && !field.isRequired) ? "\(field.label) (선택)" : field.label
    }
```

- [ ] **Step 2: 라벨 표시 지점에 헬퍼 적용**

`fieldRow` 의 비커스텀·비날짜 분기(현재 `Text(field.wrappedValue.label)`), `multilineField`
의 `Text(field.wrappedValue.label)`, 그리고 `DateFieldEditor` 호출의 `label:` 인자를
`displayLabel(for:)` 로 교체:

`fieldRow` 의 else 분기:
```swift
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayLabel(for: field.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                inputField(field)
            }
        }
```

`fieldRow` 의 date 분기:
```swift
        } else if field.wrappedValue.kind == .date {
            DateFieldEditor(label: displayLabel(for: field.wrappedValue), value: field.value)
```

`multilineField` 의 라벨:
```swift
            Text(displayLabel(for: field.wrappedValue))
                .font(.caption)
                .foregroundStyle(.secondary)
```

(placeholder 로 쓰이는 `inputField`/`TextField` 의 raw `field.label` 은 그대로 둔다.)

- [ ] **Step 3: 저장 가능 여부 계산 + 저장 버튼 비활성화**

`ItemEditView` 에 계산 속성 추가:

```swift
    private var canSave: Bool {
        Template.requiredFieldsSatisfied(draft)
    }
```

툴바의 저장 버튼에 `.disabled` 적용:

```swift
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { commit() }.disabled(!canSave)
                }
```

- [ ] **Step 4: 필수 안내 푸터 추가 (선택 사항이지만 비활성화 이유를 알려줌)**

`필드` 섹션에 푸터를 달아 저장 비활성 이유를 안내한다. 현재 `Section("필드") { ... }` 를
아래로 교체:

```swift
                Section {
                    ForEach($draft) { $field in
                        fieldRow($field)
                    }
                    Button { addCustomField() } label: {
                        Label("필드 추가", systemImage: "plus.circle.fill")
                            .font(.system(size: 15))
                    }
                    .tint(Color.actionBlue)
                } header: {
                    Text("필드")
                } footer: {
                    if !canSave {
                        Text("필수 필드를 모두 입력해야 저장할 수 있어요")
                            .foregroundStyle(Color(hex: "FF3B30"))
                    }
                }
```

- [ ] **Step 5: 빌드 + 시뮬레이터 확인**

Run: `xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED.

수동 확인(시뮬레이터, 새 항목 추가):
- "API 키 · 토큰" 유형 선택 시 필드가 6개로 보이고, 키 필드 라벨이 "API 키 · 토큰" 하나로 통합돼 있다.
- 선택 필드(엔드포인트 URL / 발급일 / 만료일 / 메모)의 라벨 끝에 "(선택)" 이 보인다.
- 필수 필드(서비스·용도 / API 키 · 토큰)에는 "(선택)" 이 없다.
- 둘 중 하나라도 비어 있으면 "저장" 버튼이 비활성(흐림)이고 푸터 안내가 보인다. 둘 다 채우면 저장 가능.
- 다른 유형(로그인 등)도 이름·주요 비밀값이 비면 저장 비활성.

- [ ] **Step 6: Commit**

```bash
git add WadeNote/Screens/ItemEditView.swift
git commit -m "feat: mark optional fields (선택) and block save until required fields filled"
```

---

## 검증 요약 (전체 완료 후)

- `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<가용 iPhone>' -only-testing:WadeNoteTests` 전체 PASS.
- 시뮬레이터에서 Task 2 Step 3 / Task 4 Step 5 수동 확인 항목 모두 충족.
- 기존 4개 유형(로그인/카드/신분증/메모)의 폼·상세·마스킹 동작에 회귀 없음(필수/선택 추가 외).
