# benchflow

성능·비용 수치를 **같은 방식으로 재고, 레포 안에 근거로 남기는** Claude Code 플러그인입니다.
같은 측정을 N번 돌려 중앙값·p90·최소·최대를 내고, 실행 환경·커밋·이름표(before/after)와 함께 `docs/bench/<이름>.jsonl`·`.md`로 저장합니다.
짝: [devflow](../devflow) · [qaflow](../qaflow) · [uiflow](../uiflow)

```
bench.sh run orders-api --label before   # 고치기 전
bench.sh run orders-api --label after    # 고친 뒤
bench.sh compare orders-api before after # 중앙값 변화, 환경이 다르면 경고
bench.sh baseline --tag qa               # 기준값 남기기
bench.sh check --tag qa                  # 기준값 대비 좋아짐/나빠짐/변화 없음, 나빠지면 알림
```

## 판정과 추천 (0.3.0)
- 지표마다 `better`(lower|higher)·`tolerance`(`"5%"` 또는 절대값)·`tags`·`entry`(코드 진입점 힌트)를 설정에 적는다. `runs: 1`이면 정확도·개수 같은 한 번 재는 값.
- `check`는 마지막 baseline과 비교해 판정하고 HTML 리포트를 남긴다. 나빠진 지표가 있으면 macOS 알림.
- **advise 스킬**: 나빠진 지표와 개선 여지가 큰 지표마다 `bench-advisor` 에이전트가 측정 경로 전체·기준 이후 diff·레포 CLAUDE.md/ADR을 읽고 추천한다. 추천마다 근거 수치·읽은 코드(`경로:줄`)·원인·변경안·예상 효과(추정)·검증 방법·위험이 있어야 하고, 없으면 "근거 부족"으로 끝낸다. 결과는 `docs/bench/advice/`, 적용은 사용자가 고른 것만.
- qaflow QA 종료 때 `qa` 태그, devflow `ship pr` 때 `pr` 태그 지표를 자동 판정(benchflow가 설치돼 있을 때만). PR 본문에 판정 표.
- `collect usage`: flow 플러그인 사용 로그 집계(AI 도구 사용 지표).

## 왜
이력서·회고의 성능 수치는 "어디서, 몇 번, 어떻게 쟀는지"가 없으면 근거가 되지 않습니다.
측정 명령·환경·횟수를 설정에 고정하고, 결과를 코드와 같은 PR에 커밋해 수치마다 근거 파일이 남게 합니다.

## 리포트
작업이 끝나면 HTML 리포트를 남깁니다: `~/.config/flow-reports/<플러그인>/<시각>-<종류>.html`.
다섯 flow 플러그인(startflow·devflow·qaflow·uiflow·benchflow)의 리포트가 한 목록 `~/.config/flow-reports/index.html`에 모입니다(최신이 위, 정상/확인 필요/실패 표시).

## 설치
```
/plugin marketplace add taehyeooo/taeng-marketplace
/plugin install benchflow@taeng-marketplace
```
설정: `~/.config/benchflow/<origin 레포 이름>.json` — 예시 [`examples/config.example.json`](examples/config.example.json). 측정 명령은 한 번 실행에 숫자 하나를 출력하면 됩니다(언어·서비스 무관).
