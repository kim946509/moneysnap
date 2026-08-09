# Money Snap iOS

iOS 17+, Swift 6, SwiftUI와 Swift Testing 기반의 native app scaffold다.

## 구조

- `MoneySnap/App`: app entry, current tab baseline과 tab별 navigation state
- `MoneySnap/Features`: Figma vertical slice를 추가할 feature 위치
- `MoneySnapTests`: public app-shell behavior를 검증하는 Swift Testing target
- `MoneySnap.xcodeproj`: app·unit test target과 shared `MoneySnap` scheme

repository의 project identifier는 `com.ansandy.moneysnap`이다. Apple Developer의 App ID나 signing team은 아직 등록하지 않았으며 외부 등록 전에 이 값을 최종 Bundle ID로 사용할지 재확인한다.

## Windows 검증

Windows에는 SwiftUI SDK와 Xcode가 없으므로 project reference, target, deployment target, bundle ID와 asset metadata만 결정론적으로 검사한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-project.ps1
```

## macOS 검증

Xcode 16 이상과 사용 가능한 iOS Simulator가 있는 Mac에서 실행한다.

```bash
bash ios/scripts/test.sh
```

이 명령이 통과하기 전에는 iOS scaffold의 native compile/test를 완료로 간주하지 않는다. Figma 화면 구현은 frame node와 393x852 snapshot AC를 가진 별도 작업에서 시작한다.

## CI/CD

- `.github/workflows/ios-ci.yml`: iOS 또는 OpenAPI contract 변경 시 GitHub-hosted `macos-15`에서 signing 없는 native test를 실행한다.
- 실패한 GitHub run만 `.xcresult`를 3일 artifact로 보관한다.
- `ci_scripts/ci_post_clone.sh`: Xcode Cloud post-clone project/toolchain 검증이다.
- archive, Apple-managed signing과 internal TestFlight 배포는 Xcode Cloud가 소유한다.

GitHub Actions에는 Apple signing credential을 넣지 않는다. 첫 Xcode Cloud workflow는 최종 Bundle ID/App Store Connect app record를 확정한 뒤 Mac/Xcode에서 활성화한다. 전체 계약은 `docs/CI_CD.md`를 따른다.
