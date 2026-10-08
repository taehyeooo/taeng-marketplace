#!/usr/bin/env bash
# 로컬 백엔드 서버 재시작: (선택) 기준 커밋으로 맞추기 → 포트의 서버 끄기 → 빌드(실행 중 JAR을 덮어쓰지 않게 끈 다음)
# → .env 불러와 실행 → health UP 대기 → 걸린 시간 기록. 트루바에서 배포·QA 전후마다 손으로 하던 순서.
#   local-server.sh restart [--ref origin/main] [--jar 경로]   빌드 후 재시작(--jar면 그 JAR로, 빌드 생략)
#   local-server.sh stop | status
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
export DEVFLOW_CONFIG="$(devflow_config)"
[ -f "$DEVFLOW_CONFIG" ] && jq -e '.local' "$DEVFLOW_CONFIG" >/dev/null || { echo "로컬 서버 설정이 없습니다: $DEVFLOW_CONFIG 의 \"local\"" >&2; exit 1; }
l() { cfg ".local.$1" "${2:-}"; }
WORKDIR=$(expand "$(l dir)"); PORT=$(l port 8080); ENVF=$(l envFile .env); BUILD=$(l build); ARTIFACT=$(l artifact)
HEALTH=$(l healthUrl "http://localhost:$PORT/actuator/health"); LOGF=$(l logFile build/bootRun.log); TIMEOUT=$(l healthTimeoutSec 180)
cd "$WORKDIR"
stop_server() {
  local p; p=$(lsof -ti tcp:"$PORT" || true)
  if [ -n "$p" ]; then kill $p; for _ in $(seq 1 30); do lsof -ti tcp:"$PORT" >/dev/null || break; sleep 1; done; echo "포트 $PORT 서버 종료"; else echo "포트 $PORT 에 서버 없음"; fi
}
case "${1:-}" in
status)
  echo "커밋: $(git log --oneline -1)"; curl -s -m 3 "$HEALTH" || echo "응답 없음"; echo ;;
stop) stop_server ;;
restart)
  shift; REF=""; JAR=""
  while [ $# -gt 0 ]; do case "$1" in --ref) REF=$2; shift 2 ;; --jar) JAR=$2; shift 2 ;; *) shift ;; esac; done
  t0=$(date +%s)
  if [ -n "$REF" ]; then
    [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "커밋하지 않은 변경이 있어 $REF 로 바꾸지 않습니다" >&2; exit 1; }
    git fetch -q && git checkout -q --detach "$REF"
  fi
  stop_server
  if [ -z "$JAR" ]; then [ -n "$BUILD" ] && { echo "빌드: $BUILD"; bash -c "$BUILD"; }; JAR=$ARTIFACT; fi
  t1=$(date +%s)
  START=$(l startCmd 'java -jar {jar}'); START=${START//\{jar\}/$JAR}  # 언어·런타임마다 다른 실행 명령은 설정으로
  (set -a; [ -f "$ENVF" ] && source "$ENVF"; set +a; nohup bash -c "$START" > "$LOGF" 2>&1 &)
  until curl -s -m 3 "$HEALTH" 2>/dev/null | grep -q '"UP"'; do
    sleep 2; [ $(( $(date +%s) - t1 )) -gt "$TIMEOUT" ] && { echo "UP이 되지 않았습니다 — 로그: $WORKDIR/$LOGF" >&2; tail -20 "$LOGF" >&2; exit 1; }
  done
  t2=$(date +%s)
  msg="커밋 $(git log --oneline -1 | cut -c1-60) · JAR $(basename "$JAR") · 빌드 $((t1-t0))초 · 기동 $((t2-t1))초"
  echo "$(date '+%F %T')	local-restart	$msg" >> "$HOME/.config/devflow/usage.log"
  echo "로컬 서버 UP — $msg" ;;
*) sed -n '2,6p' "$0"; exit 1 ;;
esac
