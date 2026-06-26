# iOS 26 + v3 Liquid Glass 리디자인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 최소 iOS를 26으로 올리고, 기존 앱 화면(홈·상세·편집·잠금)을 v3 의도 + Apple Liquid Glass로 재작업한다. 유형 그라데이션 타일·비밀값 모노스페이스는 보존한다.

**Architecture:** iOS 26 타깃 상향으로 스마트 캡처의 버전 게이트를 제거하고(가용성 게이트는 유지), 재사용 가능한 Liquid Glass 토대(브랜드 배경광 + 글래스 카드)를 만든 뒤 각 화면에 적용한다. 시각 변경이라 단위 테스트는 추가하지 않고 빌드 성공 + 기존 33개 테스트 회귀 없음 + 시뮬레이터 스크린샷으로 검증한다.

**Tech Stack:** Swift 6, SwiftUI(iOS 26 Liquid Glass: `.glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`), xcodegen, xcodebuild, GitHub Actions.

## Global Constraints

- 최소 iOS **26.0** (project.yml). iOS 18~25 폴백 없음.
- **유형 4색 그라데이션 타일·액센트·비밀값 모노스페이스 보존.** `TypeTile`은 변경 없음.
- v3의 수동 레이어드 섀도를 복제하지 않는다 — 깊이는 Liquid Glass로. 글래스 위 수동 그림자 남발 금지.
- **하드웨어 가용성 게이트 유지**: 스마트 캡처 진입점은 `SystemLanguageModel.default.availability == .available` 일 때만 노출(미지원 기기/시뮬레이터에선 숨김). 버전 게이트(`@available(iOS 26)`/`if #available(iOS 26)`)만 제거.
- 데이터 모델·저장·보안 로직 변경 없음(순수 표현 계층 + 타깃/CI).
- 시각 요소라 신규 단위 테스트 없음. 각 태스크는 **빌드 성공(양 아키텍처) + 기존 33개 단위 테스트 그린**으로 게이트. 시각 확인은 컨트롤러가 시뮬레이터 스크린샷으로 한다.
- 새 파일은 `WadeNote/DesignSystem/` 에. 추가 후 **`xcodegen generate`** 필수(로컬 .xcodeproj는 생성물·gitignore).
- 빌드/테스트(iOS 26 시뮬레이터; 가용 기기는 `xcrun simctl list devices available | grep -m1 -oE 'iPhone [0-9][^(]*' | sed 's/ *$//'`):
  - `xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'`
  - `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO`

---

### Task 1: iOS 26 타깃 상향 + CI 러너 + 버전 게이트 제거

**Files:**
- Modify: `project.yml` (deploymentTarget)
- Modify: `.github/workflows/ci.yml` (러너)
- Modify: `WadeNote/SmartCapture/FoundationModelsExtractor.swift` (버전 게이트 제거)

**Interfaces:**
- Produces: 최소 iOS 26 빌드. `SmartCaptureAvailability.isAvailable`(Bool)·`SmartCaptureEngine.makeIfAvailable() -> SmartCaptureEngine?` 시그니처는 그대로(내부 버전 게이트만 제거).

- [ ] **Step 1: 배포 타깃 상향**

`project.yml` 의 deploymentTarget 을 26.0 으로:

```yaml
  deploymentTarget:
    iOS: "26.0"
```

- [ ] **Step 2: CI 러너를 iOS 26 SDK 보유 이미지로**

`.github/workflows/ci.yml` 의 `runs-on: macos-15` 를 `macos-26` 으로 교체(Xcode 26/iOS 26 SDK 보유 러너):

```yaml
    runs-on: macos-26
```

(주: `macos-26` 러너가 아직 없으면 `macos-15` 를 유지하되 빌드 스텝 앞에 Xcode 26 선택 스텝을 추가해야 한다. 우선 `macos-26` 로 시도하고, 머지 후 CI 결과로 확인한다.)

- [ ] **Step 3: 스마트 캡처 버전 게이트 제거**

`WadeNote/SmartCapture/FoundationModelsExtractor.swift` 전체를 아래로 교체(버전 게이트만 제거, 가용성 게이트 유지):

```swift
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
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        return SmartCaptureEngine(recognizer: VisionTextRecognizer(),
                                  extractor: FoundationModelsExtractor())
    }
}
```

- [ ] **Step 4: 빌드 + 테스트**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO
```
Expected: `** BUILD SUCCEEDED **`, 33 tests pass. (CI 그린 여부는 머지/푸시 후 확인.)

- [ ] **Step 5: Commit**

```bash
git add project.yml .github/workflows/ci.yml WadeNote/SmartCapture/FoundationModelsExtractor.swift WadeNote/Info.plist
git commit -m "build: raise min iOS to 26, update CI runner, drop smart-capture version gates"
```

---

### Task 2: 디자인 토대 — 브랜드 배경광 + 글래스 카드

**Files:**
- Create: `WadeNote/DesignSystem/LiquidGlass.swift`

**Interfaces:**
- Produces:
  - `extension View { func brandGlow(_ accent: Color) -> some View }` — 상단에 옅은 액센트 라디얼을 깐 배경.
  - `struct GlassCard<Content: View>: View { init(cornerRadius: CGFloat = 18, @ViewBuilder content: () -> Content) }` — `.glassEffect` 표면 카드.

- [ ] **Step 1: 토대 컴포넌트 작성**

`WadeNote/DesignSystem/LiquidGlass.swift`:

```swift
import SwiftUI

/// 화면 상단에 은은한 브랜드 배경광(액센트 라디얼)을 까는 배경.
/// appBackground 위에 한 겹 올린다. 과하지 않게 낮은 투명도.
struct BrandGlowBackground: ViewModifier {
    let accent: Color
    func body(content: Content) -> some View {
        content.background(
            ZStack {
                Color.appBackground
                RadialGradient(
                    colors: [accent.opacity(0.16), .clear],
                    center: .top, startRadius: 0, endRadius: 380
                )
                .ignoresSafeArea()
            }
        )
    }
}

extension View {
    /// 상단 브랜드 배경광 + 앱 배경.
    func brandGlow(_ accent: Color = .actionBlue) -> some View {
        modifier(BrandGlowBackground(accent: accent))
    }
}

/// Liquid Glass 표면 카드. 깊이는 글래스가 제공하므로 수동 그림자를 쓰지 않는다.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 18
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 2: 빌드 확인**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
```
Expected: `** BUILD SUCCEEDED **`. (`.glassEffect(_:in:)` 시그니처가 SDK 와 다르면 컴파일되도록 최소 조정하되 의도 유지: regular 글래스 + 둥근 사각형 클립.)

- [ ] **Step 3: 테스트 회귀 확인**

Run: `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO`
Expected: 33 tests pass.

- [ ] **Step 4: Commit**

```bash
git add WadeNote/DesignSystem/LiquidGlass.swift
git commit -m "feat(ui): brand glow background and Liquid Glass card foundation"
```

---

### Task 3: 홈 화면 — 배경광 + 글래스 카드 + 글래스 플로팅 버튼

**Files:**
- Modify: `WadeNote/Screens/HomeView.swift`

**Interfaces:**
- Consumes: Task 2 의 `brandGlow(_:)`, `GlassCard`.

**참고:** 현재 홈은 `Color.appBackground` 배경, 카드에 `cardSurface`/`cardShadow` 사용, 플로팅 추가 버튼은 `ItemType.login.gradient` 캡슐. 그라데이션 타일(`TypeTile`)은 건드리지 않는다. 정확한 현재 코드는 파일을 읽어 확인한다.

- [ ] **Step 1: 배경을 브랜드 배경광으로**

홈 루트 배경(현재 `.background(Color.appBackground)` 등)을 `.brandGlow()` 로 교체한다. 리스트/스크롤 컨텐츠 배경은 투명 유지(`.scrollContentBackground(.hidden)` 가 이미 있으면 그대로).

- [ ] **Step 2: 항목 카드/행을 글래스로**

즐겨찾기·유형 그룹의 행 컨테이너에서 `Color.cardSurface` 솔리드 + `.shadow(... cardShadow ...)` 조합을 `GlassCard { ... }`(또는 행 배경 `.glassEffect(.regular, in: .rect(cornerRadius: ...))`)로 교체한다. 수동 `.shadow` 는 제거한다. 타일·텍스트·액센트는 그대로.

- [ ] **Step 3: 플로팅 ＋ 추가 버튼을 글래스로**

플로팅 추가 버튼 라벨에서 `.background(ItemType.login.gradient, in: Capsule())` + `.shadow(...)` 를 `.buttonStyle(.glassProminent)`(틴트는 액센트) 또는 `.glassEffect(.regular.tint(Color.actionBlue).interactive(), in: Capsule())` 로 교체한다. 빈 화면(emptyState)의 "첫 정보 추가하기" 버튼도 동일하게.

- [ ] **Step 4: 빌드 + 테스트**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO
```
Expected: BUILD SUCCEEDED, 33 tests pass.

- [ ] **Step 5: Commit**

```bash
git add WadeNote/Screens/HomeView.swift
git commit -m "feat(ui): home — brand glow, glass cards, glass add button"
```

---

### Task 4: 상세 화면 — 글래스 필드 카드 + 배경광

**Files:**
- Modify: `WadeNote/Screens/ItemDetailView.swift`

**Interfaces:**
- Consumes: Task 2 의 `brandGlow(_:)`, `GlassCard`.

**참고:** 상세는 유형별 화면이므로 배경광은 해당 항목 유형의 액센트(`item.type.accent`)를 쓴다. 비밀값 모노스페이스(`FieldRow`)는 유지. 현재 코드를 읽어 카드 컨테이너/배경 위치를 확인한다.

- [ ] **Step 1: 배경광 적용**

상세 루트 배경을 `.brandGlow(item.type.accent)` 로 한다(유형 색으로 배경광).

- [ ] **Step 2: 필드 카드 글래스화**

필드 목록을 감싸는 카드 컨테이너의 `cardSurface` 솔리드 + 수동 그림자를 `GlassCard { ... }` / `.glassEffect(.regular, in: .rect(cornerRadius:))` 로 교체. 헤더의 유형 타일은 그대로. 한 화면에 글래스 요소가 여럿이면 상위를 `GlassEffectContainer { ... }` 로 감싼다.

- [ ] **Step 3: 빌드 + 테스트**

Run: (Task 3 Step 4 와 동일한 3개 명령)
Expected: BUILD SUCCEEDED, 33 tests pass.

- [ ] **Step 4: Commit**

```bash
git add WadeNote/Screens/ItemDetailView.swift
git commit -m "feat(ui): detail — type-tinted glow, glass field cards"
```

---

### Task 5: 편집/추가 화면 — 글래스 폼 + 배경광

**Files:**
- Modify: `WadeNote/Screens/ItemEditView.swift`

**Interfaces:**
- Consumes: Task 2 의 `brandGlow(_:)`.

**참고:** 현재 편집은 `Form` + `.scrollContentBackground(.hidden)` + `.background(Color.appBackground)`. 스마트 캡처 섹션의 비주얼 개편은 **이 태스크 범위 밖(사이클 B)** — 기능/배치는 건드리지 않고, 폼 표면/배경만 토대에 맞춘다.

- [ ] **Step 1: 배경광 + 폼 표면**

`.background(Color.appBackground)` 를 `.brandGlow(type.accent)` 로 교체. Form 섹션 행 배경은 시스템 글래스/투명을 활용하되, 솔리드 카드 배경을 직접 그리던 부분이 있으면 `.glassEffect` 로 교체한다. 툴바(취소/저장)는 iOS 26 시스템 글래스가 자동 적용되므로 별도 코드 불필요.

- [ ] **Step 2: 빌드 + 테스트**

Run: (동일 3개 명령)
Expected: BUILD SUCCEEDED, 33 tests pass.

- [ ] **Step 3: Commit**

```bash
git add WadeNote/Screens/ItemEditView.swift
git commit -m "feat(ui): edit form — glow background and glass surfaces"
```

---

### Task 6: 잠금 화면 — 글래스 Face ID 카드 + 배경광

**Files:**
- Modify: `WadeNote/Screens/LockView.swift`

**Interfaces:**
- Consumes: Task 2 의 `brandGlow(_:)`, `GlassCard`.

**참고:** 현재 잠금은 `lockBgTop`/`lockBgBottom` 그라데이션 배경 + Face ID 카드. 배경광을 얹고 카드를 글래스로.

- [ ] **Step 1: 배경광 + 카드 글래스화**

기존 잠금 배경 그라데이션은 유지하되 그 위에 `.brandGlow()` 를 얹거나, 카드(Face ID 영역)를 `GlassCard { ... }` / `.glassEffect` 로 교체한다. 수동 카드 그림자는 제거.

- [ ] **Step 2: 빌드 + 테스트**

Run: (동일 3개 명령)
Expected: BUILD SUCCEEDED, 33 tests pass.

- [ ] **Step 3: Commit**

```bash
git add WadeNote/Screens/LockView.swift
git commit -m "feat(ui): lock — glow background and glass Face ID card"
```

---

## 검증 요약 (전체 완료 후)

- iOS 26 시뮬레이터에서 `xcodebuild build`/`test` 모두 성공, 기존 33개 단위 테스트 그린.
- 컨트롤러가 **홈·상세·편집·잠금** 시뮬레이터 스크린샷으로 Liquid Glass(카드·플로팅·툴바) + 상단 브랜드 배경광 적용을 확인. 라이트·다크 모두 가독성 확인.
- 유형 그라데이션 타일·액센트·비밀값 모노스페이스 보존됨.
- 스마트 캡처 진입점이 미지원(시뮬레이터)에서 여전히 숨겨짐(가용성 게이트 보존).
- 머지/푸시 후 CI(iOS 26 SDK 러너)가 그린.
