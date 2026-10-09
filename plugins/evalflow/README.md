# evalflow

AI 출력(추출·분류·요약 등)의 정확도를 **같은 정답·같은 채점으로 재고, 레포 안에 근거로 남기는** Claude Code 플러그인입니다.
채점은 오픈소스 [promptfoo](https://www.promptfoo.dev)(MIT)를 고정 버전으로 부르고, 결과를 `docs/eval/eval-<이름>.jsonl`·`.md`로 남겨 고치기 전·후를 비교합니다.
짝: [benchflow](../benchflow)(판정·지표) · [devflow](../devflow) · [qaflow](../qaflow)

```
eval.sh count place-extract              # 예상 외부 호출 수
eval.sh run place-extract --label before # 고치기 전
eval.sh run place-extract --label after  # 고친 뒤 — 새로 틀린 케이스가 있으면 알림
eval.sh diff place-extract before after  # 새로 틀림/새로 맞힘/지표 변화
```

## 왜
프롬프트·모델·후처리를 바꿀 때 "좋아진 것 같다"를 눈으로 판단하면, 다른 케이스가 깨진 것을 놓칩니다.
정답 세트와 채점을 레포에 고정하고, 결과를 코드와 같은 PR에 커밋해 정확도 수치마다 근거 파일이 남게 합니다.

## 추천(advise)
틀린 케이스가 있으면 `eval-advisor` 에이전트가 케이스 원본·프롬프트·추출/후처리 코드·최근 diff·레포 CLAUDE.md/ADR을 읽고,
실패를 패턴으로 묶어 **프롬프트로 고칠지 코드로 고칠지**를 근거와 함께 추천합니다. 추천마다 읽은 코드(`경로:줄`)·예상 효과(추정)·깨질 위험이 있어야 하고, 정답 세트에 빠진 유형은 초안으로만 제안합니다(정답은 사람이 확인). 적용은 사용자가 고른 것만.

## 무료 한도 보호
- 실행 전 예상 호출 수(시험 수 × 프롬프트 × 제공자 × `callsPerTest`)를 세고, `maxCalls`를 넘으면 멈춥니다(`--yes`로만 진행).
- `preCheck`로 남은 한도를 먼저 출력, `delayMs`·`maxConcurrency`로 분당 제한에 맞춥니다.
- 결과 공유·수집은 끕니다(`--no-share`, `PROMPTFOO_DISABLE_TELEMETRY`).

## 리포트
작업이 끝나면 HTML 리포트: `~/.config/flow-reports/evalflow/<시각>-eval.html`, 목록 `~/.config/flow-reports/index.html`.

## 설치
```
/plugin marketplace add taehyeooo/taeng-marketplace
/plugin install evalflow@taeng-marketplace
```
필요: Node 22 이상(`npx`로 promptfoo 실행), `jq`, `ruby`(macOS 기본, 시험 수 세기).
설정: `~/.config/evalflow/<origin 레포 이름>.json` — 예시 [`examples/config.example.json`](examples/config.example.json), 외부 호출 없는 예시 평가 [`examples/word-extract/`](examples/word-extract).
