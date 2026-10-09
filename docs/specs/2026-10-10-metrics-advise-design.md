# 지표 판정·개선 추천(benchflow 0.3.0) + evalflow + reviewflow 설계

2026-10-10. 사용자와 대화로 정한 범위를 옮긴다.

## 왜
- 측정은 benchflow로 같은 방식으로 남기지만, 좋아졌는지 나빠졌는지는 사람이 `compare`를 직접 돌려 봐야 했다.
- AI 출력(Trova 장소 추출)은 프롬프트를 바꿀 때마다 눈으로 비교했다.
- PR 리뷰에서 레포의 결정(ADR)·지침과 부딪히는지는 누가 따로 보지 않았다.

## 공통 원칙
- 스크립트에는 서비스 내용을 넣지 않는다. 지표·명령·정답은 설정과 각 서비스 레포에 둔다.
- 판정은 스크립트(숫자), 추천은 분석 에이전트(코드를 읽고)가 한다.
- 추천 하나 = 근거 수치 · 읽은 코드(`file:line`) · 원인 가설 · 바꿀 내용 · 예상 효과(**추정** 표시) · 검증 방법 · 위험/비용. 빠지면 추천으로 내지 않고 "근거 부족"으로 끝낸다.
- 추천 범위: 측정 경로 전체(진입점→서비스→저장소/외부 호출), 기준 커밋 이후 diff 전체, 레포 CLAUDE.md·ADR, 같은 패턴의 다른 곳.
- 추천은 자동 적용하지 않는다. 사용자가 고른 것만 진행한다.
- 알림: macOS `osascript` 알림, **나빠짐이나 새 추천이 있을 때만**. 좋아짐·변화 없음은 리포트에만.

## 1. benchflow 0.3.0
설정 필드 추가(기존 설정 그대로 동작): `better`(lower|higher, 기본 lower), `tolerance`(`"5%"` 또는 절대값, 기본 `"5%"`), `tags`(배열), `entry`(코드 진입점 힌트).
`runs: 1`, `warmup: 0`이면 한 번만 재는 값(정확도·테스트 수·호출 수).

명령:
- `baseline <이름|--tag 태그>` — 지금 값을 재서 이름표 `baseline`으로 남긴다.
- `check [--tag 태그] [--quiet]` — 태그의 지표를 재고(이름표 `check`) 마지막 baseline과 비교 → 좋아짐/나빠짐/변화 없음/비교 불가(환경 다름·기준 없음). 표·HTML 리포트, 나빠짐이면 알림. 결과 요약을 `resultsDir/_check-latest.json`에 남겨 advise가 읽는다.
- `collect usage [--since 날짜]` — `~/.config/*/usage.log`를 플러그인·종류별로 센다(AI 도구 사용 지표).
- `notify <제목> <내용>` — 공용 알림.

연결: qaflow `env stop`, devflow `ship pr`이 끝날 때 benchflow가 설치돼 있고 설정에 그 태그(`qa`/`pr`) 지표가 있으면 `check --tag`를 부른다. 없으면 조용히 건너뛴다. ship pr은 판정 표를 PR 본문에 넣는다.

추천: 스킬 `advise` + 에이전트 `bench-advisor`. `_check-latest.json`을 읽고 나빠진 지표, 그리고 변화 없음이지만 느린 지표를 분석해 `resultsDir/advice/<지표>-<날짜>.md`에 남긴다.

## 2. evalflow 0.1.0 (promptfoo)
설정 `~/.config/evalflow/<레포>.json`: `{ suites: { 이름: { config(레포 기준 promptfoo 설정 경로), preCheck?, maxCalls?, metrics?(namedScores 중 기록할 것), resultsDir? } } }`.

명령:
- `run <이름> [--label] [--filter 패턴] [--yes]` — preCheck(한도) 출력, 테스트 수가 maxCalls를 넘으면 멈춤. `npx promptfoo@0.x eval --no-share`, 수집 끄기(`PROMPTFOO_DISABLE_TELEMETRY=1`). 통과율·지표를 benchflow와 같은 형식의 `resultsDir/eval-<이름>.jsonl`·`.md`로, 케이스별 결과를 `resultsDir/eval-<이름>-cases/<시각>.json`으로 남긴다.
- `diff <이름> [A B]` — 새로 틀린/새로 맞힌 케이스.
- 스킬 `advise` + 에이전트 `eval-advisor`: 틀린 케이스를 패턴으로 묶고 프롬프트·추출 코드를 읽어 추천, 이전에 맞던 케이스가 깨질 위험과 정답 세트에 빠진 유형을 함께 적는다. 정답은 사용자가 확인한 것만 쓴다.

## 3. reviewflow 0.1.0
- 스킬 `review [PR번호|브랜치]`: `collect.sh`로 변경분·변경 파일·CLAUDE.md·ADR 목록을 모으고, 에이전트 4개(정확성·테스트·보안/시크릿·프로젝트 규칙)를 동시에 돌린 뒤 지적을 한 번 더 검증해 심각도 순으로 한국어로 낸다.
- `--comment`: PR에 댓글 하나(외부 게시라 매번 확인).
- 지적 수(심각도별)·걸린 시간을 `~/.config/reviewflow/usage.log`와 리포트에 남긴다.
- 비용: Claude Code 구독 안의 에이전트만, 유료 API 없음.

## 검증
- benchflow: Trova 로컬 서버 + 개발 DB에서 baseline → check, 일부러 tolerance를 넘게 만든 가짜 지표로 나빠짐·알림 확인.
- evalflow: 외부 호출 없는 예시 suite(echo provider)로 run·diff 확인 후, Trova suite는 Gemini 사용량을 먼저 확인하고 2~3케이스만.
- reviewflow: 실제 PR 하나에 돌려 결과 확인(댓글은 올리지 않음).
