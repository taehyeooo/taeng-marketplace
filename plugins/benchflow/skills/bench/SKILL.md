---
name: bench
description: 성능·비용 측정을 같은 방식으로 N번 돌려 통계(중앙값·p90·최소·최대)를 내고, 실행 환경·커밋·이름표와 함께 레포 안 파일로 남긴다. 고치기 전·후 비교, "측정해줘", 포트폴리오·회고에 쓸 수치가 필요할 때 쓴다.
---

# 측정 (benchflow)

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/bench.sh" list | run <이름> [--label before|after] [--runs N] | compare <이름> [A B] | baseline <이름|--tag 태그> | check [--tag 태그] | collect usage [--since 날짜]`

- `baseline`: 지금 값을 기준값으로 남긴다. `check`: 다시 재서 기준값과 비교 → 좋아짐/나빠짐/변화 없음/비교 불가(설정의 `better`·`tolerance`로 판정), 나빠지면 macOS 알림. 판정 원본은 `<resultsDir>/_check-latest.json`.
- 나빠졌거나 개선 여지가 큰 지표는 이어서 **advise 스킬**로 코드를 읽고 추천한다(자동 적용 없음).
- `collect usage`: flow 플러그인 사용 로그를 플러그인·종류별로 센다(AI 도구 사용 지표).
- 태그 `qa`는 qaflow QA 종료 때, `pr`은 devflow `ship pr` 때 자동으로 `check`된다. `pr` 지표는 **그 브랜치 코드로 재지는 것**(테스트 수·평가 정확도 등)에만 붙인다 — 로컬 서버 응답 시간은 브랜치가 아닌 실행 중인 서버를 잰다.

## 순서
1. 측정이 외부 API(예: AI 무료 한도)를 쓰면 `preCheck`로 사용량을 먼저 보고 사용자에게 남은 양을 알린다.
2. 고치기 전: `run <이름> --label before` (기능 브랜치를 만들기 전 기준 커밋에서)
3. 고친 뒤: `run <이름> --label after`
4. `compare <이름> before after` — 환경이 다르면 비교하지 않는다.
5. 결과 파일(`resultsDir/<이름>.md`, `.jsonl`)을 같은 PR에 커밋하고, 기록·PR 본문에는 "환경 · 횟수 · 중앙값 · p90"을 함께 적는다.

## 지킬 것
- 실측과 추정을 섞지 않는다. 한 번 잰 값은 "1회"라고 쓴다.
- 측정 대상·환경 이름은 설정에만 둔다(스크립트는 어떤 서비스든 같다).
