---
name: eval
description: AI 출력(추출·분류·요약 등)의 정확도를 promptfoo로 정답 대비 채점해 레포에 기록하고, 이전 기록과 비교해 새로 틀린 케이스를 찾는다. 프롬프트·모델·후처리 코드를 바꾸기 전후, "정확도 재줘", "평가 돌려줘"일 때 쓴다.
---

# AI 출력 평가 (evalflow)

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/eval.sh" list | count <이름> [--filter 정규식] [--first N] | run <이름> [--label before|after] [--filter] [--first N] [--yes] | diff <이름> [A B]`

## 순서
1. `count`로 예상 외부 호출 수를 본다. 외부 AI를 부르는 평가면 설정의 `preCheck`로 오늘 남은 한도를 확인해 **사용자에게 남은 양과 예상 호출 수를 알리고** 돌릴지 묻는다(무료 한도를 로컬·운영이 같이 쓰면 운영 몫을 남긴다).
2. 고치기 전: `run <이름> --label before`. 처음엔 `--first 2~3`으로 설정이 맞는지부터.
3. 고친 뒤: `run <이름> --label after` → 자동으로 직전 기록과 비교, 새로 틀린 케이스가 있으면 macOS 알림.
4. `diff <이름> before after`로 새로 틀림/새로 맞힘/지표 변화를 본다. 범위(`--filter`/`--first`)가 다르면 겹치는 케이스만 비교된다.
5. 틀린 케이스가 있으면 **advise 스킬**로 원인과 추천을 받는다.
6. 결과(`docs/eval/eval-<이름>.jsonl`·`.md`·`-cases/`)를 같은 PR에 커밋하고, 기록·PR 본문에 "환경 · 케이스 수 · 통과율 · 지표"를 적는다.

## 평가 설정 만들기(새 서비스)
- 레포에 `promptfooconfig.yaml` + 제공자(예: `exec: python3 provider.py` — 서비스의 실제 추출 코드를 부르는 얇은 스크립트) + 정답.
- 정답 배열은 vars에 **JSON 문자열**로 넣는다(promptfoo는 배열 vars를 조합으로 펼친다). 채점은 `javascript` assert에 `metric:` 이름을 붙여 점수(0~1)를 돌려준다 — 예시 `examples/word-extract/`.
- 정답은 사람이 확인한 것만. AI가 만든 정답 초안은 "초안"으로 표시하고 사용자 확인 후에 쓴다.
- benchflow 판정에 넣으려면 benchflow 설정 cmd에 `tail -1 docs/eval/eval-<이름>.jsonl | jq .passRate`(또는 `.metrics.recall`), `runs: 1`, `better: "higher"`.

## 지킬 것
- 결과는 외부로 공유하지 않는다(`--no-share`, 수집 끄기 — 스크립트가 강제).
- 케이스 수가 적으면(10개 미만) 통과율 변화를 일반화하지 않는다. 기록에 케이스 수를 같이 쓴다.
