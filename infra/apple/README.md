# Apple Developer infrastructure

## 현재 상태

- 사용자는 유료 Apple Developer Program 계정을 보유하고 있다.
- Apple 계정 password, 2FA code, signing certificate와 private key는 저장소에 보관하지 않는다.
- Xcode·Simulator·signing·archive는 Windows에서 실행할 수 없으며 macOS/Xcode lane에서 검증한다.
- 최종 Bundle ID는 `com.ansandy.moneysnap`으로 확정했다. Apple App ID에는 아직 등록하지 않았다.
- MVP identity provider는 Sign in with Apple 하나다. 서버의 검증·code 교환·암호화 저장 경계는 구현되어 있지만 실제 호출은 App ID와 Sign in with Apple key를 활성화하기 전까지 꺼 둔다.

## 지금 확인할 항목

- Apple Developer Program membership이 Active인지 확인
- Apple Account 2FA 활성화
- App Store Connect 로그인과 Account Holder/Admin 권한 확인
- 표시 이름 `Money Snap`의 최종 사용 승인

## Bundle ID 확정 후

1. Certificates, Identifiers & Profiles에서 explicit App ID를 등록한다. App ID와 Xcode target의 Bundle ID는 반드시 같아야 한다.
2. Sign in with Apple capability와 server key를 활성화한다.
3. App Store Connect에 iOS app record를 만든다. build upload 전 app record가 필요하다.

## iOS project와 Mac 확보 후

1. Xcode target의 Team, Bundle ID와 automatic signing을 연결한다.
2. 고정 Simulator/OS에서 build, test, snapshot을 통과시킨다.
3. Xcode에서 첫 Xcode Cloud workflow를 만든다. Apple Developer Program에 포함된 월 25 compute hours만 사용하고 유료 quota는 승인 없이 추가하지 않는다.
4. TestFlight internal build를 먼저 배포한 뒤 최종 단계에서 실기기 iPhone을 연결한다.

## 준비된 CI/CD lane

- `.github/workflows/ios-ci.yml`: `macos-15`에서 Apple credential·provisioning 없이 Xcode 기본 ad-hoc 서명으로 native test를 실행하고, visual build는 signing을 비활성화하며 실패 `.xcresult`만 짧게 보관한다.
- `ios/ci_scripts/ci_post_clone.sh`: Xcode Cloud clone 뒤 Xcode version과 `MoneySnap.xcodeproj`/shared scheme을 확인한다.
- Xcode Cloud pull request workflow: test만 실행한다.
- Xcode Cloud main release workflow: test 성공 후 archive하고 internal TestFlight group에만 post-action 배포한다.

GitHub Actions iOS CI에는 Apple certificate, provisioning profile, App Store Connect key를 주입하지 않는다. Xcode Cloud workflow는 repository 파일만으로 생성할 수 없으므로 최종 Bundle ID와 App Store Connect app record를 확정한 뒤 Mac/Xcode에서 첫 workflow/build를 시작해야 한다.

## 자동화 credential

Xcode Cloud의 기본 TestFlight post-action에는 별도 App Store Connect API key를 만들지 않는다. API 기반 tester/group 관리 같은 추가 자동화가 실제로 필요해진 뒤에만 key 작업을 연다. private key는 한 번만 다운로드할 수 있으므로 repository·log·artifact에 남기지 않고 가능한 최소 역할과 app 범위를 사용한다.

Spring Boot runtime에는 Apple activation 작업에서 `APPLE_AUTH_ENABLED=true`, `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_P8`, `APPLE_REFRESH_TOKEN_ENCRYPTION_KEY`를 저장소 밖 secret으로 주입한다. `.p8`은 env 한 줄 안에서 literal `\\n`으로 개행을 표현하며, refresh token 암호화 key는 별도의 무작위 32-byte 값을 Base64로 인코딩한다. activation 전 기본값은 `APPLE_AUTH_ENABLED=false`다.

공식 기준: [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/), [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow), [Xcode Cloud](https://developer.apple.com/xcode-cloud/), [App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)
