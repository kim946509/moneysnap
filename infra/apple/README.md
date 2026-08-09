# Apple Developer infrastructure

## 현재 상태

- 사용자는 유료 Apple Developer Program 계정을 보유하고 있다.
- Apple 계정 password, 2FA code, signing certificate와 private key는 저장소에 보관하지 않는다.
- Xcode·Simulator·signing·archive는 Windows에서 실행할 수 없으며 macOS/Xcode lane에서 검증한다.
- repository의 scaffold identifier는 `com.ansandy.moneysnap`으로 고정했다. Apple App ID에는 아직 등록하지 않았으며 외부 등록 전에 이 값을 최종 Bundle ID로 사용할지 재확인한다.

## 지금 확인할 항목

- Apple Developer Program membership이 Active인지 확인
- Apple Account 2FA 활성화
- App Store Connect 로그인과 Account Holder/Admin 권한 확인
- 표시 이름 `Money Snap`과 scaffold identifier `com.ansandy.moneysnap`의 최종 사용 승인

## Bundle ID 확정 후

1. Certificates, Identifiers & Profiles에서 explicit App ID를 등록한다. App ID와 Xcode target의 Bundle ID는 반드시 같아야 한다.
2. 필요한 capability만 활성화한다. Sign in with Apple 채택 여부가 확정되기 전에는 capability를 선등록하지 않는다.
3. App Store Connect에 iOS app record를 만든다. build upload 전 app record가 필요하다.

## iOS project와 Mac 확보 후

1. Xcode target의 Team, Bundle ID와 automatic signing을 연결한다.
2. 고정 Simulator/OS에서 build, test, snapshot을 통과시킨다.
3. Xcode에서 첫 Xcode Cloud workflow를 만든다. Apple Developer Program에 포함된 월 25 compute hours만 사용하고 유료 quota는 승인 없이 추가하지 않는다.
4. TestFlight internal build를 먼저 배포한 뒤 최종 단계에서 실기기 iPhone을 연결한다.

## 준비된 CI/CD lane

- `.github/workflows/ios-ci.yml`: `macos-15`에서 signing 없이 Simulator build/test를 실행하고 실패 `.xcresult`만 짧게 보관한다.
- `ios/ci_scripts/ci_post_clone.sh`: Xcode Cloud clone 뒤 Xcode version과 `MoneySnap.xcodeproj`/shared scheme을 확인한다.
- Xcode Cloud pull request workflow: test만 실행한다.
- Xcode Cloud main release workflow: test 성공 후 archive하고 internal TestFlight group에만 post-action 배포한다.

GitHub Actions iOS CI에는 Apple certificate, provisioning profile, App Store Connect key를 주입하지 않는다. Xcode Cloud workflow는 repository 파일만으로 생성할 수 없으므로 최종 Bundle ID와 App Store Connect app record를 확정한 뒤 Mac/Xcode에서 첫 workflow/build를 시작해야 한다.

## 자동화 credential

Xcode Cloud의 기본 TestFlight post-action에는 별도 App Store Connect API key를 만들지 않는다. API 기반 tester/group 관리 같은 추가 자동화가 실제로 필요해진 뒤에만 key 작업을 연다. private key는 한 번만 다운로드할 수 있으므로 repository·log·artifact에 남기지 않고 가능한 최소 역할과 app 범위를 사용한다.

공식 기준: [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/), [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow), [Xcode Cloud](https://developer.apple.com/xcode-cloud/), [App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)
