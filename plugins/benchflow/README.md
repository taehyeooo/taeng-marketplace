# benchflow

성능·비용 수치를 **같은 방식으로 재고, 레포 안에 근거로 남기는** Claude Code 플러그인입니다.
같은 측정을 N번 돌려 중앙값·p90·최소·최대를 내고, 실행 환경·커밋·이름표(before/after)와 함께 `docs/bench/<이름>.jsonl`·`.md`로 저장합니다.
짝: [devflow](https://github.com/taehyeooo/devflow) · [qaflow](https://github.com/taehyeooo/qaflow) · [uiflow](https://github.com/taehyeooo/uiflow)

```
bench.sh run orders-api --label before   # 고치기 전
bench.sh run orders-api --label after    # 고친 뒤
bench.sh compare orders-api before after # 중앙값 변화, 환경이 다르면 경고
```

## 왜
이력서·회고의 성능 수치는 "어디서, 몇 번, 어떻게 쟀는지"가 없으면 근거가 되지 않습니다.
측정 명령·환경·횟수를 설정에 고정하고, 결과를 코드와 같은 PR에 커밋해 수치마다 근거 파일이 남게 합니다.

## 리포트
작업이 끝나면 HTML 리포트를 남깁니다: `~/.config/flow-reports/<플러그인>/<시각>-<종류>.html`.
다섯 flow 플러그인(startflow·devflow·qaflow·uiflow·benchflow)의 리포트가 한 목록 `~/.config/flow-reports/index.html`에 모입니다(최신이 위, 정상/확인 필요/실패 표시).

## 설치
```
/plugin marketplace add taehyeooo/benchflow
/plugin install benchflow@benchflow
```
설정: `~/.config/benchflow/<origin 레포 이름>.json` — 예시 [`examples/config.example.json`](examples/config.example.json). 측정 명령은 한 번 실행에 숫자 하나를 출력하면 됩니다(언어·서비스 무관).
