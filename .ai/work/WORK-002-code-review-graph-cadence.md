---
id: WORK-002
status: done
depends_on: [WORK-001]
owner: codex
---

# Code Review Graph 갱신 주기 연결

## Intent

애플리케이션 코드가 변경될 때 `code-review-graph`를 증분 갱신하고, 그래프가 없거나 유효하지 않으면 먼저 full build하도록 구현·리뷰 루프에 연결한다.

## In scope

- 현재 저장소의 초기 그래프 full build
- 코드 변경 후 증분 update와 리뷰 전 최신성 확인 주기 정의
- 그래프 부재·손상·신규 소스 미인덱싱 시 full build fallback 정의
- 작업 템플릿, 루프, 그래프, machine-readable 하네스, 사람용 가이드와 `AGENTS.md` 연결
- 그래프 finding 수정 후 TDD 검증과 재갱신 루프 정의

## Out of scope

- 애플리케이션 코드 또는 기술 스택 생성
- 파일 저장마다 실행되는 watch 프로세스·훅·CI 도입
- 그래프 finding을 근거로 제품 범위나 AC 변경
- `.code-review-graph/` 런타임 DB 커밋

## Acceptance criteria

- [x] 그래프가 없거나 초기화되지 않았을 때 full build하는 규칙이 있다.
- [x] 소스·테스트 코드 변경 묶음마다 증분 update하고 리뷰 전에 최신성을 확인한다.
- [x] 리뷰는 minimal context에서 시작하고 위험도에 따라 change detection 상세도를 선택한다.
- [x] actionable finding을 수정하면 테스트 후 그래프를 다시 갱신하고 재검토한다.
- [x] 그래프 실행 결과를 작업 항목 Evidence에 남긴다.
- [x] 초기 full build 결과가 기록된다.

## Test seam

- 현재 그래프 통계와 하네스 문서 연결을 결정론적으로 검사한다.

## Verification

```text
code-review-graph full build 결과 확인
code-review-graph graph stats 확인
git diff --check
PowerShell Test-Path와 Select-String 기반 계약 연결 검증
```

## Evidence

- 실행: `get_minimal_context_tool(task="check graph initialization before wiring periodic code-change updates")`
- 실행: `build_or_update_graph_tool(full_rebuild=true, postprocess="full")`
- 실행: build 후 `get_minimal_context_tool(task="verify initial graph after full build and record current risk")`
- 실행: `list_graph_stats_tool`
- 실행: `python -c "import yaml; yaml.safe_load(open(r'.ai/harness.yaml', encoding='utf-8'))"`
- 실행: PowerShell `Test-Path`, `Select-String`, trailing whitespace 검사와 `git diff --check`
- 결과: 초기 full build와 graph stats 확인 성공. `0 files / 0 nodes / 0 edges`, branch `plan`, build SHA와 HEAD 일치.
- 결과: YAML 파싱, 런타임 DB와 ignore 규칙, 하네스 연결, 공백 검사가 통과했다. 최초 연결 검사에서 `.ai/LOOPS.md`의 도구명이 일반 용어로 적힌 것을 발견해 정확한 MCP 도구명으로 수정한 뒤 재검증했다.
- 리뷰: 이벤트 기반 update, 리뷰 게이트, full build fallback, TDD 수정·재update가 연결됐다. 테스트·명세·승인 경계는 그래프보다 우선한다.

## Agent rules impact

- 영향 여부: yes
- 근거: 코드 구현·리뷰 시 모든 에이전트가 따라야 하는 도구 사용 순서와 완료 게이트가 추가된다.
- 처리 결과: `AGENTS.md` 갱신 완료

## Code Review Graph

- 코드 변경 여부: no
- graph action: full build
- base: `HEAD`
- risk: low
- 결과: 0 files, 0 nodes, 0 edges
- findings: 애플리케이션 소스가 아직 없어 분석 대상 없음

## Decisions and risks

- 주기는 시간 기반이 아니라 코드 변경 이벤트와 리뷰 게이트 기반으로 둔다.
- 상시 watch·훅은 수동 주기의 유효성과 결정성이 확인된 뒤 별도 승인 작업으로 검토한다.
- 그래프는 영향 분석 보조 증거이며 테스트, 명세, 사람 승인과 제품 범위를 대체하지 않는다.
