---
name: bench
description: 성능·비용 측정을 같은 방식으로 N번 돌려 통계(중앙값·p90·최소·최대)를 내고, 실행 환경·커밋·이름표와 함께 레포 안 파일로 남긴다. 고치기 전·후 비교, "측정해줘", 포트폴리오·회고에 쓸 수치가 필요할 때 쓴다.
---

# 측정 (benchflow)

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/bench.sh" list | run <이름> [--label before|after] [--runs N] | compare <이름> [A B]`

## 순서
1. 측정이 외부 API(예: AI 무료 한도)를 쓰면 `preCheck`로 사용량을 먼저 보고 사용자에게 남은 양을 알린다.
2. 고치기 전: `run <이름> --label before` (기능 브랜치를 만들기 전 기준 커밋에서)
3. 고친 뒤: `run <이름> --label after`
4. `compare <이름> before after` — 환경이 다르면 비교하지 않는다.
5. 결과 파일(`resultsDir/<이름>.md`, `.jsonl`)을 같은 PR에 커밋하고, 기록·PR 본문에는 "환경 · 횟수 · 중앙값 · p90"을 함께 적는다.

## 지킬 것
- 실측과 추정을 섞지 않는다. 한 번 잰 값은 "1회"라고 쓴다.
- 측정 대상·환경 이름은 설정에만 둔다(스크립트는 어떤 서비스든 같다).
