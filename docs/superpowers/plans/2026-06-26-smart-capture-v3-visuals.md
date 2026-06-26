# 스마트 캡처 v3 비주얼 Implementation Plan (사이클 B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이미 동작하는 스마트 캡처(유형 안 캡처 → 온디바이스 추출 → 필드 채움)의 화면을 v3 + Liquid Glass 비주얼(캡처 카드 → 분석 중 스캔 애니메이션 → 결과)로 교체한다. 기능·보안 로직은 그대로.

**Architecture:** 스캔 애니메이션을 격리된 `ScanningView`로 분리하고, `ItemEditView`의 스마트 캡처 섹션을 상태(`analyzingImage`)에 따라 캡처 카드 / 분석 중 / 결과로 분기한다. 기존 `runSmartCapture`·추출 로직은 유지하고, 분석 중에만 캡처 이미지를 메모리에 잠깐 들고 보여준 뒤 즉시 폐기한다.

**Tech Stack:** Swift 6, SwiftUI(iOS 26, Liquid Glass `GlassCard`/`.glassEffect`), xcodegen, xcodebuild.

## Global Constraints

- **기능·보안 불변**: 기존 `runSmartCapture`/`SmartCaptureEngine`/OCR/추출 로직 변경 없음(상태/뷰만 추가). 네트워크 0, 디스크 저장 0, 로깅 0(`print`/`os_log` 금지).
- **유형 안 캡처 유지**: 유형 선택 전 글로벌 캡처·자동 유형감지 도입하지 않음.
- **이미지 수명**: 분석하는 동안만 `analyzingImage`(메모리)로 들고, 분석 종료 즉시 `defer`로 nil 폐기.
- **가용성 게이트 유지**: 스마트 캡처 섹션은 `isCreate, let engine = captureEngine` 일 때만 노출(미지원 기기 미노출).
- **Liquid Glass 언어**: 캡처 카드는 글래스 카드 룩, 스캔 라인은 `type.accent` 글로우. 기존 "확인 필요" 배지·토스트 유지.
- 시각 요소라 신규 단위 테스트 없음. 각 태스크 게이트 = **iOS 26 빌드 성공 + 기존 33개 단위 테스트 그린**. 시각 확인은 컨트롤러가 스크린샷으로.
- 새 파일은 `WadeNote/SmartCapture/` 에. 추가 후 **`xcodegen generate`** 필수(로컬 .xcodeproj는 gitignore 생성물).
- 빌드/테스트(min iOS 26; 가용 기기는 `xcrun simctl list devices available | grep -m1 -oE 'iPhone [0-9][^(]*' | sed 's/ *$//'`):
  - `xcodegen generate && xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'`
  - `xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO`

---

### Task 1: `ScanningView` — 캡처 이미지 + 스캔 라인 애니메이션

**Files:**
- Create: `WadeNote/SmartCapture/ScanningView.swift`

**Interfaces:**
- Produces: `struct ScanningView: View { let image: UIImage; let accent: Color }` — 이미지 위로 위→아래 반복 스캔 라인 + "텍스트 인식 중…".

**참고:** 순수 표현 뷰(주입된 UIImage 표시 + 애니메이션). 단위 테스트 없음 — 빌드로 검증. 로깅 금지.

- [ ] **Step 1: 작성**

`WadeNote/SmartCapture/ScanningView.swift`:

```swift
import SwiftUI

/// 분석 중 화면: 캡처 이미지 위로 스캔 라인이 위→아래 반복 이동한다.
/// 이미지는 호출부가 분석 동안만 메모리로 들고 주입한다(종료 시 폐기).
struct ScanningView: View {
    let image: UIImage
    let accent: Color
    @State private var sweep = false

    var body: some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [accent.opacity(0), accent.opacity(0.9), accent.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(height: 3)
                        .shadow(color: accent.opacity(0.7), radius: 6)
                        .offset(y: sweep ? geo.size.height - 3 : 0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: sweep)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .onAppear { sweep = true }
            HStack(spacing: 8) {
                ProgressView()
                Text("텍스트 인식 중…").foregroundStyle(Color.secondaryText)
            }
            .font(.system(size: 15))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: 빌드 + 테스트 회귀**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO
```
Expected: `** BUILD SUCCEEDED **`, 33 tests pass.

- [ ] **Step 3: Commit**

```bash
git add WadeNote/SmartCapture/ScanningView.swift
git commit -m "feat(smart-capture): scanning view with image and scan-line animation"
```

---

### Task 2: 스마트 캡처 섹션 — 캡처 카드 + 3상태 + 이미지 수명

**Files:**
- Modify: `WadeNote/Screens/ItemEditView.swift`

**Interfaces:**
- Consumes: Task 1 의 `ScanningView`; 기존 `GlassCard`, `runSmartCapture(_:engine:)`, `captureEngine`, `type`, PhotosPicker/카메라 소스.

**참고:** 현재 스마트 캡처 섹션(약 48–97행)은 `if isAnalyzing { ProgressView } else { 3개 소스 버튼 }`. 이를 (a) 캡처 카드, (b) 분석 중 = `ScanningView`, (c) 평소 = 카드로 바꾼다. 소스 컨트롤(붙여넣기 Button / PhotosPicker / 카메라 Button)은 그대로 두고 카드 안에 배치한다(별도 컴포넌트 추출 안 함 — PhotosPicker 바인딩 때문). 정확한 현재 코드는 파일을 읽어 확인한다.

- [ ] **Step 1: 분석 중 이미지 상태 추가**

`ItemEditView` 의 `@State` 들 근처(`isAnalyzing` 부근)에 추가:

```swift
    @State private var analyzingImage: UIImage?
```

- [ ] **Step 2: `runSmartCapture` 에서 이미지를 분석 동안만 보관**

기존 `runSmartCapture(_:engine:)` 의 `Task { ... }` 시작부에 이미지 세팅 + `defer` 폐기를 추가(나머지 로직 불변):

```swift
    private func runSmartCapture(_ imageData: Data, engine: SmartCaptureEngine) {
        Task {
            isAnalyzing = true
            analyzingImage = UIImage(data: imageData)
            defer { isAnalyzing = false; analyzingImage = nil }
            let result = (try? await engine.fill(imageData: imageData, type: type))
                ?? ExtractionResult(values: [:])
            let filled = applyExtraction(result, to: draft)
            needsReview = Set(filled)
            captureToast = filled.isEmpty ? "텍스트를 찾지 못했어요" : "\(filled.count)개 항목을 채웠어요 · 확인해 주세요"
        }
    }
```

- [ ] **Step 3: 섹션을 3상태 + 캡처 카드로 교체**

현재 스마트 캡처 `Section { if isAnalyzing { ... } else { ...소스 3개... } } header/footer ...` 블록을 아래로 교체. 분석 중이면 `ScanningView`, 평소엔 "캡쳐로 한 번에 채우세요" 타이틀 + 소스 3개를 글래스 카드로 감싼다(`.listRowInsets`/`.listRowBackground(.clear)` 로 Form 기본 배경 제거 후 GlassCard 적용):

```swift
                if isCreate, let engine = captureEngine {
                    Section {
                        Group {
                            if let img = analyzingImage {
                                ScanningView(image: img, accent: type.accent)
                            } else {
                                GlassCard(cornerRadius: 18) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("캡쳐로 한 번에 채우세요")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.primaryText)
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
                                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                            Button { showingCamera = true } label: {
                                                Label("카메라로 촬영해 채우기", systemImage: "camera")
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                }
                                .tint(Color.actionBlue)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("스마트 캡처")
                    } footer: {
                        Text("캡처를 넣으면 '\(type.displayName)' 칸을 자동으로 채워요. 값은 기기에서만 처리됩니다.")
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
                    .sheet(isPresented: $showingCamera) {
                        CameraPicker { data in
                            if let engine = captureEngine { runSmartCapture(data, engine: engine) }
                        }
                        .ignoresSafeArea()
                    }
                }
```

(소스 동작·`onChange`·`sheet`·footer 는 기존과 동일 — 카드 안으로 배치만 바뀜.)

- [ ] **Step 4: 빌드 + 테스트 + 시뮬레이터 확인**

Run:
```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme WadeNote -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:WadeNoteTests -parallel-testing-enabled NO
```
Expected: BUILD SUCCEEDED, 33 tests pass.

수동 확인(가능 환경 = Apple Intelligence 기기): 추가 화면에서 유형 선택 후 스마트 캡처가 **캡처 카드**로 보이고, 캡처 투입 시 **ScanningView(이미지+스캔 라인)** 가 떴다가 분석 종료 후 사라지며, 채워진 칸에 "확인 필요" 배지 + 완료 토스트가 뜬다. (시뮬레이터는 미지원이라 섹션 미노출일 수 있음 — 그 경우 가용성 게이트 정상.)

- [ ] **Step 5: Commit**

```bash
git add WadeNote/Screens/ItemEditView.swift
git commit -m "feat(smart-capture): capture card + scanning state with in-memory image"
```

---

## 검증 요약 (전체 완료 후)

- iOS 26 빌드 성공, 기존 33개 단위 테스트 그린.
- 컨트롤러가 (가능 환경에서) 캡처 카드 / 분석 중 스캔 / 결과 3상태를 스크린샷으로 확인.
- 분석 중에만 캡처 이미지가 표시되고 종료 즉시 폐기됨(메모리). 네트워크·디스크·로깅 없음 유지.
- 추출·필드 채움·"확인 필요" 배지·가용성 게이트 회귀 없음.
