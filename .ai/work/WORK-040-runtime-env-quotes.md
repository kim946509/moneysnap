---
id: WORK-040
status: active
depends_on: [WORK-039]
owner: grok
---

# runtime env quoting과 compose interpolation 분리

## Intent

Apple PEM이 Compose `.env` interpolation에 깨져 배포 health/rollback이 실패한 상태를 복구하고, 다음 CD가 R2·Apple secret을 컨테이너에 넣게 한다.

## In scope

- runtime env 값을 single-quote로 기록
- compose interpolation은 비밀 `.env`가 아닌 stub `--env-file`만 사용
- 공개 API 502 복구를 위한 main CD

## Out of scope

- deploy user를 root에서 축소
- 아이폰 실기기
- R2 토큰 재발급

## Acceptance criteria

- [x] `validate-cicd.ps1`가 quoted writer와 `--env-file` 계약을 검사한다.
- [ ] main CD가 새 image를 healthy로 올린다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File scripts\validate-cicd.ps1
```

## Agent rules impact

- 영향 여부: no
- 근거: 비밀 파일 경로는 `/opt/moneysnap/.env`로 유지하고 interpolation만 분리한다.
- 처리 결과: 갱신 불필요
