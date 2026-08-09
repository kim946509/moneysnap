---
id: WORK-008
status: done
depends_on: [WORK-007]
owner: codex
---

# Ponytail 단순성 게이트 연결

## Intent

Ponytail 플러그인을 프로젝트의 개발 루프에 연결해 불필요한 코드·추상화·의존성을 줄이되 제품·보안·테스트 기준은 보존한다.

## In scope

- `.ai/LOOPS.md`에 횡단 Ponytail 게이트 추가
- `.ai/GRAPHS.md`에 소유권·지표·카운터 지표 추가
- `.ai/harness.yaml`에 Codex 플러그인 호출 방식 기록
- `AGENTS.md`와 `docs/AI_ENVIRONMENT.md`에 로컬 스킬과 플러그인 경계 기록

## Out of scope

- Ponytail 스킬 파일의 프로젝트 로컬 복사
- 기존 Matt Pocock 스킬 교체 또는 재설치
- 제품 범위·보안 규칙·AC·테스트 기준 변경
- 자동 훅 또는 CI로 Ponytail 강제

## Acceptance criteria

- [x] 모든 코드·구조·의존성·하네스 변경에 Ponytail 게이트가 적용된다.
- [x] Ponytail은 `ponytail:ponytail` 플러그인 호출형이며 `.agents/skills/`와 skill lock에 중복 기록되지 않는다.
- [x] 최소 변경 원칙과 보안·검증·접근성 예외가 루프와 환경 문서에 명시된다.
- [x] 플러그인 추가가 제품 범위·고정 앵커를 변경하지 않는다.

## Test seam

- 문서·YAML 경로와 플러그인 provenance의 정적 검증
- 이후 코드 변경에서 Ponytail 판단과 실제 검증 명령을 작업 항목 Evidence로 확인

## Verification

```text
git diff --check
$required = @('AGENTS.md','CONTEXT.md','.ai/README.md','.ai/harness.yaml','.ai/GRAPHS.md','.ai/LOOPS.md','.ai/templates/work-item.md','docs/AI_ENVIRONMENT.md'); $missing = $required | Where-Object { -not (Test-Path -LiteralPath $_) }; if ($missing) { $missing; exit 1 }
```

## Evidence

- `ponytail:ponytail` 지침을 확인하고 full intensity의 ladder와 보안·검증 예외를 루프에 반영했다.
- Ponytail은 Codex plugin `plugin://ponytail@ponytail`으로 기록했으며 프로젝트 로컬 스킬과 분리했다.
- Ponytail 자체 자동 훅이나 CI 강제는 추가하지 않았다. 수동 게이트로 사용성을 먼저 확인한다.
- `AI environment YAML, skill lock JSON, and changed-document links` 정적 파싱 — 통과.
- `git diff --check` — 통과.
- 외부 Matt 스킬 문서의 기존 예제 링크 3개는 이번 변경 범위 밖이며 수정하지 않았다.

## Agent rules impact

- 영향 여부: yes
- 근거: 프로젝트의 개발 루프와 외부 플러그인 사용 경계가 추가되었다.
- 처리 결과: `AGENTS.md`와 `docs/AI_ENVIRONMENT.md`를 루프·하네스 변경과 함께 동기화했다.

## Code Review Graph

- 코드 변경 여부: no
- graph action: skipped
- base: N/A
- risk: 문서·하네스 변경만 포함
- findings와 처리 결과: 애플리케이션 소스·테스트 변경이 없어 graph update를 생략했다.

## Decisions and risks

- 결정: Ponytail은 모든 개발 루프에 적용하는 단순성 게이트이며 별도 순차 오케스트레이터가 아니다.
- 결정: 프로젝트 로컬 설치 원칙을 유지하기 위해 Codex plugin 호출 provenance만 하네스에 기록한다.
- 위험: 플러그인 미설치 에이전트에서는 이 게이트를 호출할 수 없으므로 해당 어댑터에서 동등한 최소성 검사를 제공해야 한다.
