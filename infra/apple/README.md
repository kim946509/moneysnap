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

Windows에서 Xcode Run은 할 수 없다. TestFlight 업로드는 GitHub-hosted `macos-26` / Xcode 26의 `.github/workflows/ios-testflight.yml`이 한다. 성공한 `main` iOS CI 또는 Actions `workflow_dispatch`가 `ios-testflight` secret으로 archive한 뒤 App Store Connect에 올린다. archive는 iOS Development 인증서를 만들지 않고 Apple Distribution cloud signing만 쓴다. 앱은 `https://moneysnap-server.ansandy.co.kr`에 붙는다.

```text
gh secret set APPLE_TEAM_ID --env ios-testflight
gh secret set APP_STORE_CONNECT_ISSUER_ID --env ios-testflight
gh secret set APP_STORE_CONNECT_KEY_ID --env ios-testflight
gh secret set APP_STORE_CONNECT_API_KEY_P8 --env ios-testflight
```

`.p8`은 대화에 붙이지 않는다. API key는 Team key여야 하며 Certificates, Identifiers & Profiles 접근과 cloud-managed Apple Distribution signing이 필요하다. Individual/app-scoped key와 Admin/App Manager 역할만으로는 `-allowProvisioningUpdates`가 실패한다. 업로드 후 App Store Connect에서 본인 Apple ID를 Internal Tester로 넣고 아이폰 TestFlight에서 설치한다.

## iOS project와 TestFlight

1. App Store Connect iOS app record와 explicit App ID `com.ansandy.moneysnap`이 있어야 한다.
2. App Store Connect API key를 만들어 `ios-testflight` environment secret에만 넣는다. 대화·Git에 `.p8`을 붙이지 않는다.
3. `main`에서 `iOS TestFlight` workflow를 수동 실행하거나, 성공한 `main` iOS CI가 같은 workflow를 이어서 실행하게 한다.
4. App Store Connect에서 본인 Apple ID를 Internal Tester로 넣은 뒤 아이폰 TestFlight에서 설치한다.

로컬 Mac의 Xcode Team 연결은 interactive Run/pixel 작업에만 필요하다. repository에 `DEVELOPMENT_TEAM`을 커밋하지 않는다.

## 준비된 CI/CD lane

- `.github/workflows/ios-ci.yml`: `macos-15`에서 Apple credential·provisioning 없이 Xcode 기본 ad-hoc 서명으로 native test를 실행하고, visual build는 signing을 비활성화하며 실패 `.xcresult`만 짧게 보관한다.
- `.github/workflows/ios-testflight.yml`: `ios-testflight` environment의 App Store Connect API key로 `main` archive와 upload만 수행한다. 같은 레포이며 서버 CD와 secret을 공유하지 않는다.
- `ios/scripts/write-testflight-export-options.sh`: `app-store-connect` / `destination=upload` ExportOptions를 생성한다.
- `ios/ci_scripts/ci_post_clone.sh`: 예전 Xcode Cloud hook이며 현재 TestFlight lane이 아니다.

GitHub Actions iOS CI와 pull request job에는 Apple certificate, provisioning profile, App Store Connect key를 주입하지 않는다.

## 자동화 credential

TestFlight CD는 App Store Connect **Team** API key가 필요하다. Team key는 팀의 모든 앱에 적용된다. Individual/app-scoped key는 provisioning에 사용할 수 없다. private key는 한 번만 다운로드할 수 있으므로 repository·log·artifact·대화에 남기지 않고 `ios-testflight` environment에만 넣는다. Sign in with Apple 서버 `.p8`과 같은 파일을 재사용하지 않는다.

Spring Boot runtime Apple 값은 GitHub `server-development` environment secret으로만 보관하고, `main` development CD가 `/opt/moneysnap/runtime.env`에 쓴다. pull request CI와 iOS workflow에는 주입하지 않는다.

등록 이름:

- `APPLE_AUTH_ENABLED` — `true` 또는 `false`
- `APPLE_CLIENT_ID` — `com.ansandy.moneysnap`
- `APPLE_TEAM_ID` — 10자 Apple Developer Team ID
- `APPLE_KEY_ID` — Sign in with Apple Key ID
- `APPLE_PRIVATE_KEY_P8` — `AuthKey_<KEY_ID>.p8` 내용. 대화·Git에 붙이지 말고 `gh secret set APPLE_PRIVATE_KEY_P8 --env server-development < AuthKey_<KEY_ID>.p8`
- `APPLE_REFRESH_TOKEN_ENCRYPTION_KEY` — 무작위 32-byte Base64. Apple `.p8`이 아니며 서버가 refresh token을 암호화할 때 쓴다.

`.p8`은 여러 줄로 secret에 넣어도 되며 CD가 env 한 줄의 literal `\n`으로 정규화한다. 필수 값이 비면 CD는 host `.env`를 덮어쓰지 않고 실패한다.

공식 기준: [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/), [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow), [App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api), [Distributing your app for beta testing](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/)
