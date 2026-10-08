#!/usr/bin/env bash
# 작업 기록 초안: 지금 브랜치에서 사실(이슈 번호, 커밋, 바뀐 파일, 테스트 수·실패, 최근 배포·QA 기록)을 모아
# work-record 틀로 출력한다. "왜·어떻게 결정했는지"는 대화에서 채우고, 숫자는 여기서 가져온다(실측만).
#   record-draft.sh [기준 브랜치=origin/main]
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
export DEVFLOW_CONFIG="$(devflow_config)"
BASE=${1:-origin/main}
branch=$(git branch --show-current); issue=$(printf '%s' "$branch" | grep -oE '#[0-9]+' | head -1)
mb=$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")
title=$(git log --format=%s "$mb"..HEAD | tail -1 | sed -E 's/^[a-z]+: //')
tests="(빌드 결과 없음)"
if ls build/test-results/test/*.xml >/dev/null 2>&1; then
  n=$(grep -ho '<testcase ' build/test-results/test/*.xml | wc -l | tr -d ' ')
  f=$(grep -l '<failure' build/test-results/test/*.xml 2>/dev/null | wc -l | tr -d ' ')
  tests="전체 ${n}개, 실패 ${f}개 (로컬, $(date -r build/test-results/test '+%F %H:%M') 빌드)"
fi
DLOG=$(expand "$(cfg .deploy.log "$HOME/.config/devflow/deploys.log")"); QLOG=$(expand "$(cfg .qa.log "$HOME/.config/qaflow/qa.log")")
lastdeploy=$( [ -f "$DLOG" ] && jq -s 'map(select(.kind == "deploy")) | last // empty' "$DLOG" | jq -r '"\(.at) \(.commit) — 전체 \(.totalSeconds)초, UP \(.upSeconds)초, 확인 \(.checks)"' 2>/dev/null || echo "없음")
lastqa=$( [ -f "$QLOG" ] && tail -1 "$QLOG" | jq -r '"\(.at) — \(.seconds)초, 탭 \(.taps)번, 남은 패치 \(.patchLeft)"' 2>/dev/null || echo "없음")
cat <<MD
## $(date +%F) ${title:-제목} (${issue:-#이슈})

### 범위
- (왜 했는지 — 사용자가 한 말을 따옴표로)

### 방법 비교
| 항목 | 방법 | 결정 |
|---|---|---|
| | | |

### 한 것
$(git log --format='- %s (%h)' "$mb"..HEAD)
- 바뀐 파일: $(git diff --stat "$mb"..HEAD | tail -1 | sed 's/^ *//')

### 확인
- 테스트: $tests
- 최근 배포(운영): $lastdeploy
- 최근 QA(로컬 서버 + 개발 DB): $lastqa
- (실측 수치는 환경과 측정 방법을 함께. 추정은 "추정"이라고)

### 남은 것
- 
MD
echo "$(date '+%F %T')	record-draft	$(git rev-parse --show-toplevel) ${issue:-}" >> "$HOME/.config/devflow/usage.log"
