---
id: WORK-011
status: complete
depends_on: [WORK-010]
owner: codex
---

# 공개 저장소 README

## Intent

공개 저장소 방문자가 Money Snap의 제품 목적, 현재 구현 상태, 기술 구조, 로컬 검증과 보안 경계를 첫 화면에서 정확히 이해하도록 루트 `README.md`를 만든다.

## In scope

- 제품 소개와 Figma Home reference
- 현재 완료 단계와 다음 게이트
- iOS·Spring Boot·Neon·Cloudflare/Ubuntu Docker 기술 구조
- Windows 서버/iOS 정적 검증과 macOS 네이티브 검증 명령
- 환경변수, CI/CD와 비밀값 취급 규칙
- 상세 기준 문서와 개발 프로세스 링크
- 현재 threshold 상태와 충돌하는 `ios/README.md` 한 줄 동기화

## Out of scope

- 제품·인증·그룹 정책 변경
- application source와 인프라 변경
- 외부 배포와 PR 병합

## Acceptance criteria

- [x] 루트 `README.md`가 현재 제품과 WORK-010 완료 상태를 설명한다.
- [x] 실행·검증 명령과 환경변수 이름이 저장소의 실제 계약과 일치한다.
- [x] 모든 상대 링크와 이미지 경로가 존재한다.
- [x] 실제 secret, connection string, 계정 credential을 포함하지 않는다.
- [x] iOS 문서가 visual threshold 활성화 상태와 일치한다.

## Test seam

- 문서 경로·상대 링크 존재 여부와 secret placeholder 사용을 PowerShell로 검사한다.
- 저장소 계약 검증과 `git diff --check`를 실행한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
git diff --check
```

## Evidence

- 실행 명령: README 상대 링크·HTML image path·필수 환경변수·credential 유사 문자열 PowerShell 검사, iOS project/visual baseline 검증, CI/CD 계약 검증, `git diff --check`
- 결과: `Money Snap root README contract: OK`, iOS 두 계약과 CI/CD 계약 모두 `OK`, diff 오류 없음
- 리뷰: PRD, architecture, CI/CD, infra, server/iOS README와 실제 Gradle/Xcode/visual manifest 값을 대조했다. 목표 MVP와 현재 read-only fixture 구현을 구분했고 실제 secret 값은 포함하지 않았다.

## Agent rules impact

- 영향 여부: no
- 근거: README는 기존 기준 문서와 완료 상태를 요약하며 stack, 불변 규칙, 승인 경계 또는 검증 명령을 바꾸지 않는다.
- 처리 결과: `AGENTS.md` 갱신 불필요

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: `9e09d62`
- risk: documentation-only
- findings와 처리 결과: application source 변경이 없어 생략한다.

## Decisions and risks

- README는 현재 구현과 목표 MVP를 구분해 아직 없는 인증·저장 API를 구현된 것처럼 보이지 않게 한다.
- 로컬 Neon 파일의 실제 값은 읽거나 문서에 복제하지 않고 `.env.example`의 변수 이름만 사용한다.
