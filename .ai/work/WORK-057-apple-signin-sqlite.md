---
id: WORK-057
status: active
depends_on: []
owner: grok
---

# Empty origin SQLite에서 Apple 로그인 복구

## Intent

Neon 데이터를 이전하지 않은 origin SQLite에서도 Sign in with Apple이 새 세션을 만들 수 있게 한다.

## In scope

- 원본 client identity token은 nonce를 필수로 검증한다. 토큰 교환 `id_token`에 nonce claim이 없을 때만, client token nonce가 이미 맞으면 로그인을 거절하지 않는다
- iOS Sign in with Apple nonce를 View `@State`가 아니라 in-flight capture에 둔다
- 사용자 id를 SQLite TEXT UUID로 저장한다
- development CD로 서버를 재배포한다

## Out of scope

- Neon dump/restore
- Apple Developer Console에서 key 재발급 (코드로 불가)
- 사진/Snap 데이터 복구

## Acceptance criteria

- [x] 교환 id_token에 nonce가 없어도 client token nonce가 맞으면 authorize가 성공한다
- [x] 잘못된 nonce claim은 계속 거절한다
- [x] 로그인 후 `users.id`의 SQLite typeof는 `text`다
- [x] iOS는 Apple sheet 완료 시 in-flight raw nonce를 사용한다
- [ ] identity 테스트와 서버 CD가 통과한다

## Test seam

- `AppleIdentityTokenVerifierTests`
- `AppleAuthorizationPersistenceIntegrationTests`
- `IdentitySessionServiceIntegrationTests`
- `AppleNonceTests`

## Verification

```text
cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.*" --no-daemon --console=plain
```

## Evidence

- 실행 명령: `cd server; .\gradlew.bat test --tests "com.ansandy.moneysnap.identity.*" --no-daemon --console=plain` 그리고 `cd server; .\gradlew.bat test --no-daemon --console=plain`
- 결과: 둘 다 BUILD SUCCESSFUL. identity 패키지 41s, 전체 server test 45s.
- 리뷰: 배포 후 CD 결과로 보완

## Agent rules impact

- 영향 여부: no
- 근거: Sign in with Apple 단독 인증, 15분 access, 180일 refresh, nonce 검증(claim이 있을 때)은 유지한다. 제품 범위와 승인 경계를 바꾸지 않는다.
- 처리 결과: `AGENTS.md` 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped
- findings와 처리 결과: Windows 세션에서 code-review-graph MCP 없음

## Decisions and risks

- 빈 SQLite는 의도된 전환이다. 예전 Neon 세션은 복구하지 않고 재로그인을 허용한다.
- Apple `.p8`은 GitHub secret이며 이 작업에서 값을 읽거나 로그에 쓰지 않는다.
