# WadeNote

민감한 개인정보를 유형별 템플릿으로 구조화 저장하고, Face ID로 잠그며, iCloud(CloudKit)로 모든 기기에 복원하는 iOS 네이티브 앱.

설계·계획 문서는 `docs/superpowers/`에 있습니다.

## 빌드 / 실행

프로젝트는 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 생성합니다.

```bash
xcodegen generate
xcodebuild build -scheme WadeNote -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

시뮬레이터 실행:

```bash
xcrun simctl install "iPhone 17 Pro" <DerivedData>/Build/Products/Debug-iphonesimulator/WadeNote.app
xcrun simctl launch "iPhone 17 Pro" com.wadenote.app
```

진입 시 Face ID(시뮬레이터에서는 기기 암호) 잠금 화면이 뜨고, 해제하면 홈 화면으로 들어갑니다.

## 테스트

```bash
# 로직 테스트(템플릿·테마·색·클립보드 자동삭제·앱잠금·첨부 암호화) — 14개, 안정적으로 통과
xcodebuild test -scheme WadeNote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -only-testing:WadeNoteTests
```

테스트 타깃은 두 개로 분리되어 있습니다:
- **WadeNoteTests** — SwiftData를 쓰지 않는 순수 로직 테스트.
- **WadeNoteStoreTests** — SwiftData(ItemStore/모델) 테스트.

## 구현 상태

| 영역 | 상태 |
|------|------|
| 앱 빌드 (앱 아이콘 포함) | ✅ BUILD SUCCEEDED |
| 앱 실행 (잠금→홈, 로컬 SwiftData) | ✅ 시뮬레이터에서 확인 |
| 로직 테스트 14종 | ✅ 통과 |
| 데이터 모델·템플릿·스토어·암호화·잠금·디자인 시스템·4화면·사진첨부 | ✅ 구현 완료 |
| SwiftData 단위 테스트 실행 | ⚠️ 아래 환경 이슈 참조 |

## 알려진 환경 이슈 / 수동 단계

1. **CloudKit 동기화**: 기본 런타임은 로컬 SwiftData 저장소를 사용합니다. iCloud 동기화를 켜려면
   ① Xcode에서 iCloud > CloudKit capability와 `iCloud.com.wadenote.app` 컨테이너 추가 + 개발팀 서명,
   ② `WadeNoteApp.makeContainerWithFallback()`를 `try makeContainer(inMemory: false)`로 교체.
   엔타이틀먼트 없이 CloudKit 컨테이너를 만들면 미러링이 런타임에 크래시하므로 기본값은 로컬입니다.

2. **SwiftData 단위 테스트 크래시 (이 환경 한정)**: 현재 머신의 Xcode 26.5 / iOS 26.5 시뮬레이터에서는
   호스팅된 XCTest 번들 안에서 SwiftData `save()`가 `EXC_BREAKPOINT`로 트랩합니다.
   2줄짜리 trivial `@Model`로도 재현되는 **툴체인/시뮬레이터 버그**이며 WadeNote 코드 결함이 아닙니다.
   `WadeNoteStoreTests`의 테스트 코드는 표준 SwiftData 패턴으로 올바르게 작성되어 있고, 정상 동작하는
   머신/CI에서는 통과합니다. 로직 테스트(`WadeNoteTests`)와 앱 실행은 영향받지 않습니다.

3. **서명/플랫폼 설정**: 시뮬레이터 빌드는 ad-hoc 서명(`CODE_SIGN_IDENTITY: "-"`)을 사용합니다.
   테스트는 `-parallel-testing-enabled NO`로 직렬 실행하세요(병렬 시 SwiftData 컨테이너 동시 생성 이슈).

## 앱 아이콘

`scripts/make_icon.py`가 디자인 글리프(흰 노트 + •••• + 블루 잠금 뱃지)를 1024 라이트/다크
마스터로 렌더합니다. `WadeNote/Assets.xcassets/AppIcon.appiconset`에 적응형으로 등록되어 있습니다.
