# Money Snap iOS

iOS 17+, Swift 6, SwiftUI와 Swift Testing 기반의 native app scaffold다.

## 구조

- `MoneySnap/App`: app entry, current tab baseline과 tab별 navigation state
- `MoneySnap/Features`: Figma vertical slice를 추가할 feature 위치
- `MoneySnapTests`: public app-shell behavior와 `contracts/examples/v1/**` canonical HTTP fixture decode를 검증하는 Swift Testing target
- `MoneySnapUITests`: DEBUG visual scenario로 Home 표시와 My 이동, unknown scenario fail-closed를 검증하는 XCUITest target
- `MoneySnap.xcodeproj`: app·unit test·UI test target과 shared `MoneySnap` scheme

최종 Bundle ID는 `com.ansandy.moneysnap`이다. Sign in with Apple entitlement는 `MoneySnap/MoneySnap.entitlements`에 있다. 실기기 서명 team은 GitHub `ios-testflight` secret의 `APPLE_TEAM_ID`로 넣으며 repository에 `DEVELOPMENT_TEAM`을 커밋하지 않는다.

## 아이폰에서 직접 열어보기

Windows에서 Xcode Run으로 기기에 올릴 수는 없다. 같은 레포의 GitHub-hosted TestFlight CD로 IPA를 올린다. 레포를 나누지 않는다.

1. App Store Connect의 Money Snap iOS app record가 있는지 확인한다.
2. `ios-testflight` environment에 Team ID와 App Store Connect API key secret을 넣는다. 값은 대화에 붙이지 않는다.
3. `main`에서 Actions `iOS TestFlight`를 실행한다. 성공한 `main` iOS CI도 같은 workflow를 이어서 실행한다.
4. App Store Connect에서 본인 Apple ID를 Internal Tester로 넣은 뒤 아이폰 TestFlight에서 설치한다.
5. 앱 API는 `https://moneysnap-server.ansandy.co.kr`이다. Sign in with Apple과 새 Snap/group API는 그 서버에 이 코드가 배포된 뒤에만 동작한다.
6. 첫 실행에서 카메라·사진 권한을 허용하고 Apple로 로그인한다.

GitHub Actions iOS CI(`ios-ci.yml`)에는 signing certificate와 App Store Connect key를 넣지 않는다.

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
- `.github/workflows/ios-testflight.yml`: `main`에서만 `ios-testflight` secret으로 archive하고 App Store Connect에 업로드한다.
- 실패한 GitHub run만 `.xcresult`를 3일 artifact로 보관한다.
- 모든 성공한 visual lane은 app/reference/overlay/diff/report를 7일 artifact로 보관한다.
- `scripts/write-testflight-export-options.sh`: TestFlight export plist를 생성한다.
- `ci_scripts/ci_post_clone.sh`: 예전 Xcode Cloud hook이며 현재 archive lane이 아니다.

GitHub Actions iOS test job에는 Apple signing credential을 넣지 않는다. 전체 계약은 `docs/CI_CD.md`를 따른다.
