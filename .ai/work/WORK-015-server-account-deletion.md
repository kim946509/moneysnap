---
id: WORK-015
status: done
depends_on: [WORK-014]
owner: codex
---

# 서버 계정 탈퇴와 Apple authorization revoke

## Intent

로그인한 사용자가 Sign in with Apple로 재인증한 뒤 Apple authorization과 Money Snap 계정·모든 session·연결 데이터를 안전하게 삭제한다.

## In scope

- 인증이 필요한 `DELETE /api/v1/account`
- Apple 재인증 credential/code 검증과 현재 Money Snap 사용자 subject 일치 확인
- 저장소 밖 encryption key로 Apple refresh token 복호화
- Apple `/auth/revoke`의 `refresh_token` revoke 요청
- revoke 성공 후 PostgreSQL user 삭제와 FK cascade를 통한 모든 session·연결 데이터 삭제
- revoke 실패 시 계정과 session을 유지하고 재시도 가능한 오류 반환
- 실제 PostgreSQL, fake Apple HTTP endpoint, HTTP bearer 통합 테스트

## Out of scope

- Apple server-to-server notification
- iOS 탈퇴 확인·재인증·Keychain 삭제 UI
- 아직 존재하지 않는 Snap·group·media schema
- Apple Developer portal activation과 배포

## Acceptance criteria

- [x] 유효한 bearer session과 같은 Apple subject의 재인증으로 탈퇴하면 Apple refresh token을 revoke하고 204를 반환한다.
- [x] 성공 후 사용자, Apple identity, 모든 device session과 현재 존재하는 연결 데이터가 남지 않는다.
- [x] 재인증 subject가 현재 사용자와 다르면 401이며 Apple revoke와 DB 삭제를 수행하지 않는다.
- [x] Apple revoke가 실패하면 502이며 계정과 모든 Money Snap session을 유지해 재시도할 수 있다.
- [x] 성공한 탈퇴 뒤 기존 access·refresh token을 모두 거부한다.
- [x] raw Apple refresh token, private key, client secret과 Money Snap token을 로그·DB·저장소에 새로 남기지 않는다.

## Test seam

- Apple revoke seam: fake HTTP endpoint로 form contract, 200 idempotency와 오류 변환을 검증한다.
- account application seam: PostgreSQL 18 Testcontainers에서 subject ownership, revoke-before-delete, cascade와 failure preservation을 검증한다.
- HTTP seam: bearer 인증·재인증 request·204/401/502와 성공 후 token 거부를 MockMvc로 검증한다.

## Verification

```text
cd server; .\gradlew.bat test --no-daemon --console=plain
cd server; .\gradlew.bat bootJar --no-daemon --console=plain
git diff --check
```

## Evidence

- 실행 명령: `cd server; .\gradlew.bat test --no-daemon --console=plain`
- 결과: `BUILD SUCCESSFUL`, 59 tests, failures 0, errors 0. PostgreSQL 18 Testcontainers로 subject 소유권, revoke failure 보존, user·identity·session·refresh token cascade와 기존 token 거부를 검증했다.
- 실행 명령: `cd server; .\gradlew.bat bootJar --no-daemon --console=plain`
- 결과: `BUILD SUCCESSFUL`, production JAR 생성.
- 실행 명령: `git diff --check`, `git diff --cached --check`
- 결과: 모두 exit 0.
- 리뷰: Standards 재리뷰 hard violation 0건, Spec 재리뷰 누락·scope creep 0건. client-secret 생성 실패의 502 변환, HTTP/DB seam 분리, refresh-token cascade evidence를 보강했다.

## Agent rules impact

- 영향 여부: yes
- 근거: 계정 탈퇴·Apple revoke 서버 경계가 완료되어 `AGENTS.md`의 다음 인증 단계가 server-to-server event로 바뀐다.
- 처리 결과: 기준 문서 `docs/DEVELOPMENT_PLAN.md`를 먼저 갱신하고 `AGENTS.md` 현재 단계 요약을 동기화했다.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: incremental update 완료
- base: `30b0a87`
- risk: medium (`0.60`)
- graph state: 437 nodes, 3893 edges, 72 files. staged 새 파일을 포함해 full rebuild 없이 증분 update했다.
- findings와 처리 결과: 우선 검토 대상인 `AccountController`, `AccountDeletionService`, revoke adapter를 HTTP·PostgreSQL·fake Apple endpoint 테스트와 양축 리뷰로 확인했다. 구조적 test gap 48건은 package-private test 연결을 인식하지 못한 휴리스틱 결과이며 관련 경로는 59개 전체 테스트로 검증됐다.

## Decisions and risks

- Apple revoke는 refresh token 기준으로 먼저 수행하며, Apple의 [200 idempotent revoke 계약](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens)을 이용해 DB 삭제 실패 시 재시도 가능성을 유지한다.
- Apple revoke가 실패한 상태에서 로컬 계정을 성공 처리하지 않는다.
- PostgreSQL user 삭제가 현재와 이후의 owner FK를 cascade하도록 각 기능 schema에서 계약을 유지한다.
