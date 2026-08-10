---
id: WORK-001
status: done
depends_on: []
owner: codex
---

# AGENTS.md 현재화와 동기화 루프

## Intent

현재 프로젝트 단계에 맞게 `AGENTS.md`를 고치고, 이후 프로젝트 규칙 변화가 있을 때 최신성을 빠뜨리지 않고 검증하는 루프를 하네스에 연결한다.

## In scope

- 현재 제품·기술·구현 상태와 다음 승인 경계를 `AGENTS.md`에 반영
- 기준 문서, 검증 명령, 경로, 승인 경계 변경 시 `AGENTS.md` 영향 검토를 의무화
- 작업 템플릿, 루프, 그래프, machine-readable 하네스와 사람용 가이드에 동기화 절차 연결
- 자동 훅 도입 전 수동 루프와 결정론적 검증으로 운영

## Out of scope

- 제품 범위·정책 변경
- 기술 스택·아키텍처 결정
- 애플리케이션 코드 생성
- Git 훅 또는 커스텀 실행기 추가

## Acceptance criteria

- [x] `AGENTS.md`가 현재 기획·UX 후반, 기술 설계·구현 전 상태를 정확히 설명한다.
- [x] 모든 작업 항목에서 `AGENTS.md` 영향 여부와 처리 결과를 기록한다.
- [x] 문서 동기화 루프가 `AGENTS.md` 최신성 검사를 포함한다.
- [x] 하네스 개선은 사용자 명시 요청으로도 시작할 수 있고 승인·롤백 규칙을 유지한다.
- [x] 관련 문서의 경로와 내부 참조가 실제 파일과 일치한다.

## Test seam

- 변경된 하네스 문서의 경로·참조 존재 여부와 Git whitespace 오류를 검증한다.

## Verification

```text
git diff --check
PowerShell Test-Path 기반 필수 하네스 파일 검증
PowerShell Select-String 기반 AGENTS.md 동기화 계약 연결 검증
```

## Evidence

- 실행 명령: `git diff --check`
- 실행 명령: `python -c "import yaml; yaml.safe_load(open(r'.ai/harness.yaml', encoding='utf-8'))"`
- 실행 명령: PowerShell `Test-Path`, `Select-String`, trailing whitespace 검사
- 결과: YAML 파싱, 대상 파일 공백 검사, 필수 경로와 동기화 계약 연결 검사가 모두 통과했다. `git diff --check`는 오류 없이 종료했으며 기존 파일의 LF→CRLF 경고만 출력했다.
- 리뷰: `AGENTS.md`에는 장기 실행 계약과 현재 단계만 두고 실시간 작업 상태는 `.ai/work/`에 남겼다. 자동 훅은 검증 전 도입하지 않았다.

## Agent rules impact

- 영향 여부: yes
- 근거: `AGENTS.md`의 현재 단계와 지속 동기화 계약 자체를 변경하는 작업이다.
- 처리 결과: `AGENTS.md` 갱신 완료

## Decisions and risks

- 초기에는 자동 훅을 추가하지 않는다. 수동 루프가 반복적으로 유효하고 결정론적임이 확인된 뒤 별도 승인 작업으로 자동화한다.
- `AGENTS.md`에는 단기 작업 진행률을 복제하지 않고, 단계·승인 경계·권위 문서·실행 규칙만 둔다.
