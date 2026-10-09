---
name: advise
description: evalflow 평가에서 틀린 케이스를 패턴으로 묶고, 프롬프트·추출·후처리 코드를 직접 읽어 근거 있는 개선안(프롬프트 수정 vs 코드 수정)을 추천한다. "왜 틀렸어", "정확도 올리려면", 새로 틀린 케이스 알림을 받았을 때 쓴다.
---

# 평가 개선 추천 (evalflow)

## 순서
1. 대상 기록: `docs/eval/eval-<이름>.jsonl`의 마지막 줄과 그 `raw`(promptfoo 케이스 원본). 이전 기록이 있으면 `eval.sh diff <이름>`으로 새로 틀린 케이스를 먼저 본다.
2. `eval-advisor` 에이전트를 부른다. 넘길 것: 평가 이름, 설정(`~/.config/evalflow/<레포>.json`의 그 평가), promptfoo 설정 경로, 케이스 원본 경로, 새로 틀린 케이스 목록, 레포 경로.
3. 돌아온 추천을 검증한다: 인용한 `경로:줄`을 직접 열어 확인, 틀린 케이스 예시가 원본과 맞는지, 예상 효과에 "추정"이 붙었는지, 레포 CLAUDE.md·ADR과 충돌이 없는지. 틀린 추천은 뺀다.
4. `docs/eval/advice/<이름>-<YYYYMMDD>.md`에 남긴다.
5. 추천이 하나 이상이면 알림: `osascript -e 'display notification "<이름>: 추천 N건" with title "evalflow"'`.
6. 사용자에게 패턴·추천·깨질 위험을 보여주고 **무엇을 적용할지 묻는다**. 정답 세트에 추가할 케이스 제안은 정답 초안으로만 보여주고, 사용자가 확인한 것만 정답 파일에 넣는다.
7. 적용했다면 `eval.sh run <이름> --label after-<짧은 설명>`으로 다시 채점하고 advice 파일 끝에 전/후를 덧붙인다.
