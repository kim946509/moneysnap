# Work graph state

활성 작업은 `.ai/templates/work-item.md`를 복사해 이 디렉터리에 둔다. 파일 이름은 `WORK-001-short-name.md` 형식을 사용한다.

- `depends_on`으로 blocking edge를 표현한다.
- `ready`는 모든 의존성과 결정이 해결된 상태다.
- `active` 작업은 원칙적으로 한 에이전트당 하나만 둔다.
- 모든 작업은 `Agent rules impact`에 `AGENTS.md` 영향 여부와 근거를 기록한다.
- 코드 변경 작업은 `Code Review Graph`에 build/update, 기준점, 위험도와 finding 처리 결과를 기록한다.
- `done` 전에는 Verification과 Evidence를 채운다.
- 완료된 작업은 제품 또는 기술 의사결정 가치가 있을 때만 보존하고, 일시적 실행 로그는 커밋하지 않는다.
