---
id: WORK-058
status: active
depends_on: [WORK-057]
owner: grok
---

# Apple client JWT만 검증돼도 로그인

## Intent

재설치 후에도 Apple 로그인이 실패하므로, client identity token이 Apple JWKS로 검증되면 token 교환 실패와 무관하게 Money Snap 세션을 발급한다.

## In scope

- `AppleAuthorizationAdapter`: client token 검증 성공 시 `/auth/token` 실패를 로그인 거절로 쓰지 않음
- Apple token JSON을 `id_token`/`refresh_token` 키로 읽음
- 회귀 테스트

## Out of scope

- Neon 데이터 이전
- Apple Developer Console key 재발급

## Acceptance criteria

- [x] 유효한 client identity token + Apple token endpoint 400이면 authorize가 성공한다
- [x] token 교환이 성공하면 기존처럼 refresh token을 암호화해 저장한다
- [x] 잘못된 client nonce는 계속 거절한다
- [ ] 서버 테스트와 development CD가 통과한다

## Test seam

- `AppleAuthorizationPersistenceIntegrationTests`
- `AppleTokenClientTests`

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.*" --no-daemon --console=plain
```

## Evidence

- 실행 명령: `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.*" --no-daemon --console=plain` 그리고 `cd server; .\gradlew.bat test --no-daemon --console=plain`
- 결과: 둘 다 BUILD SUCCESSFUL

## Agent rules impact

- 영향 여부: no
- 근거: Sign in with Apple 검증은 유지한다. token 교환 실패 시 Apple revoke용 refresh는 비워 둘 수 있다. 계정 탈퇴는 재인증 시점의 교환에 의존한다.
- 처리 결과: `AGENTS.md` 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
