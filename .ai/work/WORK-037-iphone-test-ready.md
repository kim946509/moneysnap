---
id: WORK-037
status: active
depends_on: [WORK-017, WORK-025, WORK-036]
owner: grok
---

# 아이폰 실기기 테스트 준비와 사진 업로드 연결

## Intent

이미 구현된 MVP 서버·iOS 기능을 아이폰에서 Sign in with Apple과 사진 기록까지 시험할 수 있게, 기기 capability와 media upload를 연결한다.

## In scope

- Sign in with Apple entitlement와 사진/카메라 사용 설명
- JPEG intent→upload→complete 클라이언트와 기록 command의 `imageRef`
- 앨범/카메라에서 고른 사진을 정규화한 뒤 업로드
- iOS project 정적 검증
- 아이폰 설치 경로 문서 (Xcode Cloud/TestFlight는 Mac 1회)

## Out of scope

- live R2 Adapter와 새 R2 secret 등록
- `SERVER_SSH_PORT` 값 추측 변경
- Windows에서 archive/TestFlight/실기기 서명
- WORK-033 전체 visual/performance release candidate
- AC·보안 규칙 완화

## Acceptance criteria

- [x] `MoneySnap.entitlements`에 Sign in with Apple `Default`가 있고 Debug/Release가 참조한다.
- [x] Info.plist에 카메라·사진 라이브러리 사용 설명이 있다.
- [x] 사진이 있으면 media intent/upload/complete 후 `imageRef`로 Snap을 저장한다.
- [x] 사진 없이 기록하면 `imageRef`를 보내지 않는다.
- [x] upload 성공 후 record 재시도는 같은 `imageRef`를 유지하고 upload를 다시 하지 않는다.
- [x] entitlement·media·pbx ID 계약을 검사한다. 전체 `validate-project.ps1`은 기존 visual baseline probe에서 실패한다.

## Test seam

- `MediaClientTests`: intent/upload/complete HTTP 순서
- `SnapCaptureModelTests`: 사진 기록의 `imageRef`와 retry freeze

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
```

## Evidence

- 실행 명령: pbx object IDs, `CODE_SIGN_ENTITLEMENTS`, Sign in with Apple entitlement, camera/photo usage strings
- 결과: `device-contract: OK`
- 리뷰:

## Agent rules impact

- 영향 여부: no
- 근거: 제품 불변 규칙과 승인 경계는 그대로다. TestFlight/CD는 기존 Mac·SSH gate를 유지한다.
- 처리 결과: 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: skipped this increment if graph tools unavailable on Windows worktree
- findings와 처리 결과:

## Decisions and risks

- 아이폰 설치는 Windows에서 완료할 수 없다. 코드와 capability만 준비한다.
- 서버 사진 저장은 현재 MemoryObjectStore라 컨테이너 재시작 후 사라진다. live R2는 별도 승인 작업이다.
- development API는 이 코드가 `main`에 배포되기 전에는 구버전이다.
