# CloudKit 동기화 활성화 가이드

코드·설정 스캐폴딩은 모두 끝나 있습니다. 아래 5단계만 Xcode에서 진행하면 iCloud 동기화가 켜집니다.
유료 Apple Developer 계정이 필요합니다.

> 이미 준비된 것: `WadeNote.entitlements`(CloudKit 서비스 + `iCloud.com.wadenote.app` 컨테이너 + 푸시),
> `Info.plist`의 `UIBackgroundModes: [remote-notification]`, CloudKit 호환 모델, `WADENOTE_CLOUDKIT`
> 플래그로 게이트된 런타임 컨테이너.

---

## 1. 프로젝트 열기

```bash
cd WadeNote
xcodegen generate      # .xcodeproj 생성(이미 있으면 생략 가능)
open WadeNote.xcodeproj
```

## 2. 서명(Team) 설정 — 자동 관리로 전환

`project.yml`은 시뮬레이터 ad-hoc 서명(`CODE_SIGN_IDENTITY: "-"`)이 기본입니다. 본인 팀으로 바꿉니다.

**방법 A — Xcode UI에서 (권장, 가장 쉬움)**
1. 프로젝트 네비게이터에서 **WadeNote** 프로젝트 → **WadeNote** 타깃 선택.
2. **Signing & Capabilities** 탭.
3. **Automatically manage signing** 체크.
4. **Team** 드롭다운에서 본인 팀 선택.
5. **Bundle Identifier**가 `com.wadenote.app`입니다. 본인 팀에 이미 등록된 ID가 아니면
   고유한 역도메인(예: `com.<yourname>.wadenote`)으로 바꿉니다.
   바꿨다면 **6단계**의 컨테이너 ID도 같이 맞춥니다.

> Xcode UI에서 바꾼 서명 설정은 `.xcodeproj`에 저장됩니다. 단, `xcodegen generate`를 다시 돌리면
> `project.yml` 기준으로 덮어쓰여 초기화됩니다. 영구 반영하려면 **방법 B**도 함께 적용하세요.

**방법 B — project.yml에 영구 반영**
`project.yml`의 `WadeNote` 타깃 `settings.base`에서 주석 처리된 줄을 해제/수정합니다:
```yaml
        DEVELOPMENT_TEAM: "YOUR_TEAM_ID"          # 예: ABCDE12345
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) WADENOTE_CLOUDKIT"
        CODE_SIGN_STYLE: Automatic
```
그리고 같은 파일 상단 `settings.base`의 `CODE_SIGN_IDENTITY: "-"`, `CODE_SIGNING_REQUIRED: "NO"`는
앱을 실기기에 올릴 때 방해될 수 있으니, CloudKit 빌드에서는 제거하거나 Xcode 자동 서명에 맡깁니다.
Team ID는 **Apple Developer 사이트 > Membership**에서 확인할 수 있습니다.

## 3. iCloud capability 확인

Signing & Capabilities 탭에 **iCloud**가 보이고 **CloudKit**이 체크돼 있어야 합니다
(엔타이틀먼트에 이미 들어 있어 보통 자동으로 잡힙니다). 컨테이너 목록에
`iCloud.com.wadenote.app`(또는 6단계에서 바꾼 ID)가 체크돼 있는지 확인합니다.
없으면 **+ Capability** → **iCloud** 추가 후 CloudKit 체크.

## 4. CloudKit 코드 플래그 켜기

방법 B를 적용했다면 자동으로 켜집니다. UI만 쓴다면:
타깃 → **Build Settings** → **Active Compilation Conditions**(검색) → Debug/Release에
`WADENOTE_CLOUDKIT` 추가.

이 플래그가 꺼져 있으면 코드가 계속 로컬 저장소를 쓰므로 **반드시** 켜야 합니다.

## 5. iCloud 로그인 + 동기화 검증

1. 시뮬레이터/기기 **설정 앱 → Apple 계정 로그인**(같은 Apple ID).
2. WadeNote 실행 → 항목 추가.
3. 두 번째 기기(또는 시뮬레이터 2대)에서 같은 Apple ID로 로그인 후 앱 실행 → 항목이 나타나면 성공.
   (동기화는 즉시가 아닐 수 있습니다. 몇 초~수십 초.)
4. 앱을 지웠다 다시 깔아도 iCloud에서 복원되는지 확인.

> 디버깅: Xcode 콘솔에서 `NSPersistentCloudKitContainer` 로그 확인.
> CloudKit 대시보드(developer.apple.com → CloudKit Database)에서 레코드가 올라오는지 볼 수 있습니다.

---

## 6. 번들/컨테이너 ID를 바꿨다면

`com.wadenote.app`을 본인 역도메인으로 바꿨다면 세 곳을 일치시킵니다:

| 위치 | 항목 |
|------|------|
| `project.yml` | `PRODUCT_BUNDLE_IDENTIFIER` |
| `WadeNote/WadeNote.entitlements` | `com.apple.developer.icloud-container-identifiers`의 `iCloud.<bundle-id>` |
| `WadeNote/App/WadeNoteApp.swift` | `static let cloudKitContainerID` |

컨테이너 ID 관례는 `iCloud.` + 번들 ID 입니다.

## 7. 출시 전: 스키마 Production 승격

첫 실행 시 SwiftData가 CloudKit **Development** 환경에 스키마를 자동 생성합니다.
앱 출시(또는 TestFlight) 전에 **CloudKit 대시보드 → Schema → Deploy to Production**으로 승격해야
실사용자 기기에서 동기화됩니다.
