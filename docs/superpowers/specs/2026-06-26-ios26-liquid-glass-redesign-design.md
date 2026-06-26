# iOS 26 상향 + v3 리디자인(Liquid Glass) — 설계 문서

작성일: 2026-06-26
참고 디자인: WadeNote v3.dc.html (claude.ai/design 프로젝트 `679173b2-7839-4875-bf02-5f142b1ddaaa`)

## 목표

최소 iOS를 26으로 올리고, 기존 앱 화면을 **v3 디자인 의도 + Apple Liquid Glass**로
한 번에 재작업한다(화면 이중 작업 방지). 스마트 캡처 신규 화면은 이 디자인 언어 위에
별도 사이클(B)에서 만든다 — 본 스펙(사이클 A) 범위 밖.

## 설계 원칙 — v3 의도를 Liquid Glass로 "번역"

v3 목업은 iOS 26 이전 디자인이라 **수동 레이어드 섀도·브랜드 글로우**로 깊이를 줬다.
iOS 26에서는 **Liquid Glass가 깊이를 시스템으로 제공**하므로, v3를 글자 그대로 복제하지
않고 **의도(색 정체성·위계·레이아웃)를 Liquid Glass 재질로 번역**한다. 글래스 위에
수동 그림자를 남발하지 않는다(HIG 준수).

**보존(브랜드 정체성)**: 유형 4색 그라데이션 타일(로그인 파랑·카드 초록·신분증 보라·
API 틸·메모 회색), 액센트 색, 비밀값 모노스페이스 표시.

## 1. 디자인 토대 — `WadeNote/DesignSystem/`

### 배경
- `Color.appBackground`(light `#f4f2ee`)는 **이미 v3 따뜻한 오프화이트와 일치** → 변경 없음.
- **상단 브랜드 배경광**: 화면 상단에 액센트 컬러의 매우 옅은 라디얼 그라데이션 한 겹을
  올리는 재사용 가능한 뷰/모디파이어를 추가(`BrandGlow` 또는 `.brandGlowBackground()`).
  과하지 않게(투명도 낮게), 다크모드에서도 자연스럽게.

### 깊이 = Liquid Glass
- 카드·컨테이너 표면은 솔리드/수동 섀도 대신 **`.glassEffect()`** 로 표현. iOS 26 API:
  `.glassEffect(_:in:)`, 그룹은 `GlassEffectContainer { ... }`, 버튼은
  `.buttonStyle(.glass)` / `.glassProminent`.
- 헤어라인 보더는 글래스 가장자리로 흡수(별도 1px 보더 추가하지 않음).

### 토큰 정리(`Colors.swift`)
- 필요한 글래스 틴트/배경광 헬퍼만 추가. 기존 색 토큰·`TypeTile` 그라데이션은 유지.
- 재사용 글래스 카드 컨테이너(예: `GlassCard` 뷰)를 도입해 화면들이 공통으로 쓰게 한다
  (중복 글래스 코드 방지, 한 곳에서 조정 가능).

## 2. 화면별 처리

| 화면 (파일) | v3 의도 + Liquid Glass 번역 |
|---|---|
| **홈** (`HomeView.swift`) | 오프화이트 배경 + 상단 브랜드 배경광. 즐겨찾기/유형 그룹의 행·카드 → 글래스 표면. 플로팅 "＋ 추가" 버튼 → `.buttonStyle(.glass)`(또는 glassProminent). 내비·검색바는 시스템 자동 글래스. **그라데이션 타일 그대로**. |
| **상세** (`ItemDetailView.swift`) | 필드 카드 컨테이너 → 글래스. 눈/복사 버튼은 툴바 글래스. 헤더에 유형 타일 + 옅은 배경광. 비밀값 모노스페이스 유지. |
| **편집/추가** (`ItemEditView.swift`) | Form 섹션 배경을 글래스 톤으로. 취소/저장 툴바 글래스. **스마트 캡처 섹션의 비주얼은 사이클 B**(여기선 기능/배치 유지). |
| **잠금** (`LockView.swift`) | Face ID 카드 → 글래스. 배경광. |
| **루트** (`RootView.swift`) | 배경·전환을 토대에 맞춤. |
| **타일** (`TypeTile.swift`) | 변경 없음(브랜드 그라데이션 유지). |
| **여러 글래스 요소** | 한 화면에 글래스가 여럿이면 `GlassEffectContainer`로 묶어 굴절·모핑 일관성 확보. |

각 화면은 "한 번에" 토대(배경광/글래스 카드) 적용으로 재작업한다. 픽셀 디테일은
구현 중 실제 iOS 26 시뮬레이터 스크린샷으로 반복 조정한다.

## 3. iOS 26 상향 + CI

### 최소 타깃
- `project.yml` `deploymentTarget.iOS` **"18.0" → "26.0"**, `xcodegen generate`.
- 스마트 캡처의 **버전 게이트 제거**(이제 불필요): `FoundationModelsExtractor`의
  `@available(iOS 26, *)`, `SmartCaptureAvailability`/`makeIfAvailable()`의
  `if #available(iOS 26, *)` / `guard #available`.
- **하드웨어 가용성 게이트는 유지**: iOS 26이어도 Apple Intelligence는 일부 기기에만
  있으므로 `SystemLanguageModel.default.availability == .available` 체크는 그대로 둔다
  → 미지원 기기에선 스마트 캡처 진입점이 계속 숨겨진다.

### CI (선행 검증 필수)
- 최소 26 + Liquid Glass + FoundationModels 는 **Xcode 26 / iOS 26 SDK**가 필요하다.
  현재 `.github/workflows/ci.yml`은 `runs-on: macos-15`.
- **이 러너에 Xcode 26 SDK가 없으면 머지 시 main CI가 실패한다.** 사이클 A 초반에:
  - CI 러너를 iOS 26 SDK 보유 이미지로 갱신(`runs-on: macos-26` 가용 시 사용, 또는
    `maxim-lobanov/setup-xcode` / `xcode-select`로 Xcode 26 지정).
  - 빌드 destination/SDK가 iOS 26인지 확인.
- 이 작업을 **첫 태스크로** 두어 토대가 CI에서 그린인지 먼저 확정한다.

## 4. 테스트 / 검증

- Liquid Glass·배경광은 시각 요소라 **단위 테스트 없음**. 검증은:
  - **iOS 26 시뮬레이터 빌드 성공**(로컬 + CI 양 아키텍처).
  - **화면별 before/after 스크린샷**(홈·상세·편집·잠금) — 글래스/배경광 적용 확인.
  - **글래스 × 그라데이션 대비·가독성** 확인(라이트·다크 모두).
- **기존 33개 단위 테스트 회귀 없음** 확인.
- 스마트 캡처 진입점이 미지원(시뮬레이터)에서 여전히 숨겨지는지 확인(가용성 게이트 보존).

## 스코프 밖

- **스마트 캡처 v3 비주얼 화면**(캡처 카드 시트·분석 중·결과 화면) — 사이클 B.
- 신규 기능 추가 없음. 데이터 모델·저장·보안 로직 변경 없음(순수 표현 계층 + 타깃/CI).
- iOS 18~25 폴백 디자인 — 최소 26으로 올리므로 불필요.

## 성공 기준

- `project.yml` deploymentTarget 26.0, `xcodegen generate` 후 빌드 성공.
- 스마트 캡처의 iOS 26 버전 게이트가 제거되고(가용성 게이트는 유지) 빌드·동작 정상.
- CI가 iOS 26 SDK 러너에서 그린.
- 홈·상세·편집·잠금에 Liquid Glass(카드·플로팅·툴바) + 상단 브랜드 배경광이 적용되고,
  유형 그라데이션 타일·액센트·모노스페이스 비밀값은 보존된다.
- 라이트·다크 모두 가독성 유지, 기존 33개 단위 테스트 회귀 없음.
