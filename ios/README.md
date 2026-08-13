# Money Snap iOS

iOS 17+, Swift 6, SwiftUI와 Swift Testing 기반의 native app scaffold다.

## 구조

- `MoneySnap/App`: app entry, current tab baseline과 tab별 navigation state
- `MoneySnap/Features`: Figma vertical slice를 추가할 feature 위치
- `MoneySnapTests`: public app-shell behavior와 `contracts/examples/v1/**` canonical HTTP fixture decode를 검증하는 Swift Testing target
- `MoneySnapUITests`: DEBUG visual scenario로 Home 표시와 My 이동, unknown scenario fail-closed를 검증하는 XCUITest target
- `MoneySnap.xcodeproj`: app·unit test·UI test target과 shared `MoneySnap` scheme

최종 Bundle ID는 `com.ansandy.moneysnap`이다. Apple Developer의 explicit App ID와 배포 signing team 연결은 아직 등록하지 않았으며 별도 Apple activation 작업에서 진행한다.

## Windows 검증

Windows에는 SwiftUI SDK와 Xcode가 없으므로 project reference, target, deployment target, bundle ID, asset metadata와 canonical identity fixture test resource 연결을 결정론적으로 검사한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\validate-visual-baseline.ps1
```

## macOS 검증

고정 기준선인 Xcode 16.4, iPhone 16, iOS 18.5 Simulator가 있는 Mac에서 실행한다.

```bash
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
```

첫 명령은 Swift unit+UI test를 실행한다. 두 번째 명령은 앱을 한 번 build/install한 뒤 manifest 순서대로 Home `9:2`, My `77:798`의 screenshot과 overlay/diff/report를 모두 생성한다. 한 화면이 threshold를 초과해도 나머지 증거까지 만든 후 실패한다. `VisualReferences/manifest.json`이 ordered scenario, 393x852 reference의 node·checksum과 Simulator 계약을 고정한다. `WORK-010` 완료 기준으로 diff는 MAE `0.05`, mismatched pixel ratio `0.43` threshold를 강제하며 초과 시 CI가 실패한다.

## CI/CD

- `.github/workflows/ios-ci.yml`: iOS 또는 OpenAPI contract 변경 시 GitHub-hosted `macos-15`에서 Apple credential·provisioning 없이 Xcode 기본 ad-hoc 서명으로 unit+UI test를 실행하고, 단일 build-once runner로 visual evidence를 생성한다.
- 실패한 GitHub run만 `.xcresult`를 3일 artifact로 보관한다.
- 모든 성공한 visual lane은 app/reference/overlay/diff/report를 7일 artifact로 보관한다.
- `ci_scripts/ci_post_clone.sh`: Xcode Cloud post-clone project/toolchain 검증이다.
- archive, Apple-managed signing과 internal TestFlight 배포는 Xcode Cloud가 소유한다.

GitHub Actions에는 Apple signing credential을 넣지 않는다. 첫 Xcode Cloud workflow는 explicit App ID와 App Store Connect app record를 만든 뒤 Mac/Xcode에서 활성화한다. 전체 계약은 `docs/CI_CD.md`를 따른다.
