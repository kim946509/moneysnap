# Apple Developer infrastructure

## 현재 상태

- 사용자는 유료 Apple Developer Program 계정을 보유하고 있다.
- Apple 계정 password, 2FA code, signing certificate와 private key는 저장소에 보관하지 않는다.
- Xcode·Simulator·signing·archive는 Windows에서 실행할 수 없으며 macOS/Xcode lane에서 검증한다.
- 최종 Bundle ID는 `com.ansandy.moneysnap`으로 확정했다. explicit App ID와 App Store Connect iOS app record는 사용자가 생성했다.
- MVP identity provider는 Sign in with Apple 하나다. 서버의 검증·code 교환·암호화 저장 경계는 구현되어 있고, 실제 Apple 호출은 `server-development`의 `APPLE_AUTH_ENABLED=true`와 `.p8`이 CD로 배포된 뒤에만 켜진다.

## 지금 확인할 항목

- Apple Developer Program membership이 Active인지 확인
- Apple Account 2FA 활성화
- App Store Connect 로그인과 Account Holder/Admin 권한 확인
- 표시 이름 `Money Snap`의 최종 사용 승인

## Bundle ID 확정 후

1. Certificates, Identifiers & Profiles에서 explicit App ID를 등록한다. App ID와 Xcode target의 Bundle ID는 반드시 같아야 한다.
2. Sign in with Apple capability와 server key를 활성화한다.
3. App Store Connect에 iOS app record를 만든다. build upload 전 app record가 필요하다.

## 아이폰 실기기 설치

Windows 작업 트리에서는 archive/TestFlight/실기기 Run을 완료할 수 없다. Mac에서 `ios/MoneySnap.xcodeproj`를 열고 Team을 연결한 뒤 기기에 Run 하거나, 같은 Mac에서 첫 Xcode Cloud workflow를 만들어 Internal TestFlight로 배포한다. 앱은 `https://moneysnap-server.ansandy.co.kr`에 붙는다.

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

Spring Boot runtime Apple 값은 GitHub `server-development` environment secret으로만 보관하고, `main` development CD가 `/opt/moneysnap/.env`에 쓴다. pull request CI와 iOS workflow에는 주입하지 않는다.

등록 이름:

- `APPLE_AUTH_ENABLED` — `true` 또는 `false`
- `APPLE_CLIENT_ID` — `com.ansandy.moneysnap`
- `APPLE_TEAM_ID` — 10자 Apple Developer Team ID
- `APPLE_KEY_ID` — Sign in with Apple Key ID
- `APPLE_PRIVATE_KEY_P8` — `AuthKey_<KEY_ID>.p8` 내용. 대화·Git에 붙이지 말고 `gh secret set APPLE_PRIVATE_KEY_P8 --env server-development < AuthKey_<KEY_ID>.p8`
- `APPLE_REFRESH_TOKEN_ENCRYPTION_KEY` — 무작위 32-byte Base64. Apple `.p8`이 아니며 서버가 refresh token을 암호화할 때 쓴다.

`.p8`은 여러 줄로 secret에 넣어도 되며 CD가 env 한 줄의 literal `\n`으로 정규화한다. 필수 값이 비면 CD는 host `.env`를 덮어쓰지 않고 실패한다.

공식 기준: [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/), [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow), [Xcode Cloud](https://developer.apple.com/xcode-cloud/), [App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)
