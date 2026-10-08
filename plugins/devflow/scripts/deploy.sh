#!/usr/bin/env bash
# 단일 서버(JAR + systemd) 배포를 한 번에: 빌드 → 진행 중 작업 확인 → 전송 → 해시 비교 → 백업 → 교체 → 재시작
# → UP 대기 → 배포 후 확인 → 기록. 트루바에서 손으로 20번 넘게 반복하던 순서를 그대로 옮겼다.
#   사용: deploy.sh [--dry-run] [--skip-build] [--checks-only]
#   --checks-only: 배포 없이 배포 후 확인만 다시 돌리고 기록한다
# 설정: ~/.config/devflow/<레포>.json 의 "deploy" (examples/config.example.json 참고)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
DRY=0; SKIP_BUILD=0; CHECKS_ONLY=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; --skip-build) SKIP_BUILD=1 ;; --checks-only) CHECKS_ONLY=1 ;; esac; done

conf=$(devflow_config)
# 처음 찾은 설정을 고정한다 — 앱 폴더로 cd한 뒤에 다시 찾으면 다른 레포의 설정을 보게 된다(첫 실사용에서 발견).
export DEVFLOW_CONFIG="$conf"
[ -f "$conf" ] && jq -e '.deploy' "$conf" >/dev/null || { echo "배포 설정이 없습니다: $conf 의 \"deploy\"" >&2; exit 1; }
d() { cfg ".deploy.$1" "${2:-}"; }
HOST=$(d host); KEY=$(expand "$(d sshKey)"); REMOTE=$(d remotePath); OWNER=$(d owner root); SERVICE=$(d service)
ARTIFACT=$(d artifact); BUILD=$(d build); HEALTH=$(d healthUrl); TIMEOUT=$(d healthTimeoutSec 240)
PRE=$(d preCheck); LOG=$(expand "$(d log "$HOME/.config/devflow/deploys.log")")
SSH=(ssh -i "$KEY" -o BatchMode=yes "$HOST")

step() { printf '\n[%s] %s\n' "$(date +%T)" "$*"; }
# 단계별 시간(초) — 어디에 시간이 드는지 기록해 회고·개선에 쓴다
declare -a TIMES=(); mark=$(date +%s)
lap() { local now; now=$(date +%s); TIMES+=("$1=$(( now - mark ))"); mark=$now; }
start=$(date +%s)
COMMIT=$(git rev-parse --short HEAD); SUBJECT=$(git log -1 --format=%s)
STAMP=$(date +%Y%m%d-%H%M%S); BACKUP="$REMOTE.bak-$STAMP"

step "배포 대상: $COMMIT $SUBJECT → $HOST:$REMOTE (서비스 $SERVICE)"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "추적 중인 파일에 커밋하지 않은 변경이 있습니다 — 커밋된 코드만 배포합니다." >&2; exit 1
fi
if [ "$DRY" = 1 ]; then
  echo "(dry-run) 빌드: ${BUILD:-없음} / 산출물: $ARTIFACT / 백업: $BACKUP / 헬스: $HEALTH"
  echo "(dry-run) 사전 확인: ${PRE:-없음} / 확인 항목: $(jq -r '[.deploy.checks[]?.name] | join(", ")' "$conf")"
  exit 0
fi

# 배포 후 확인: 확인 명령이 반복문의 입력을 먹지 않게 </dev/null, "0건"이면 grep이 1로 끝나도 멈추지 않게 || true
# (첫 실제 배포에서 세션 쿠키 확인(grep -c → 0, 종료 코드 1)에서 스크립트가 멈춰 기록이 안 남았다)
run_checks() {
  results=(); failed=0; CHECK_ROWS="[]"
  while IFS=$'\t' read -r name command expect; do
    [ -z "$name" ] && continue
    got=$(bash -c "$command" </dev/null 2>/dev/null | tr -d '[:space:]' || true)
    if [ "$got" = "$expect" ]; then echo " ✓ $name ($got)"; results+=("$name=ok"); r="정상($got)"; else echo " ✗ $name (기대 $expect, 실제 $got)"; results+=("$name=FAIL($got)"); failed=1; r="실패(기대 $expect, 실제 $got)"; fi
    CHECK_ROWS=$(jq -c --arg n "$name" --arg r "$r" '. + [[$n,$r]]' <<< "$CHECK_ROWS")
  done < <(jq -r '.deploy.checks[]? | [.name, .cmd, .expect] | @tsv' "$conf")
}
write_log() {  # $1 종류(deploy|checks) $2 UP까지 초 $3 전체 초
  mkdir -p "$(dirname "$LOG")"
  jq -nc --arg at "$(date '+%F %T')" --arg kind "$1" --arg commit "$COMMIT" --arg subject "$SUBJECT" --arg hash "${LOCAL_HASH:-}" \
    --arg backup "${BACKUP:-}" --arg up "$2" --arg total "$3" --arg checks "${results[*]:-}" \
    --arg steps "${TIMES[*]:-}" '{at:$at, kind:$kind, commit:$commit, subject:$subject, hash:$hash, backup:$backup, upSeconds:$up, totalSeconds:$total, steps:$steps, checks:$checks}' >> "$LOG"
  echo "$(date '+%F %T')	$1	$COMMIT	up=${2}s total=${3}s checks=${results[*]:-}" >> "$HOME/.config/devflow/usage.log"
}

if [ "$CHECKS_ONLY" = 1 ]; then
  if [ -f "$ARTIFACT" ]; then LOCAL_HASH=$(shasum -a 256 "$ARTIFACT" | cut -c1-16); fi
  BACKUP=""; step "배포 후 확인만 다시"; run_checks; write_log checks "" ""; exit $failed
fi

mark=$(date +%s)
if [ "$SKIP_BUILD" = 0 ] && [ -n "$BUILD" ]; then step "빌드: $BUILD"; bash -c "$BUILD"; fi
lap build
[ -f "$ARTIFACT" ] || { echo "산출물이 없습니다: $ARTIFACT" >&2; exit 1; }
LOCAL_HASH=$(shasum -a 256 "$ARTIFACT" | cut -c1-16)

if [ -n "$PRE" ]; then
  step "사전 확인(진행 중 작업 등): $PRE"
  bash -c "$PRE" || { echo "사전 확인 실패 — 배포를 멈춥니다." >&2; exit 1; }
fi
lap precheck

step "전송 ($(du -h "$ARTIFACT" | cut -f1))"
TMP="/tmp/devflow-$COMMIT.jar"
scp -q -i "$KEY" -o BatchMode=yes "$ARTIFACT" "$HOST:$TMP"
REMOTE_HASH=$("${SSH[@]}" "sha256sum $TMP | cut -c1-16")
[ "$LOCAL_HASH" = "$REMOTE_HASH" ] || { echo "해시 불일치: 로컬 $LOCAL_HASH / 서버 $REMOTE_HASH" >&2; exit 1; }
echo "해시 일치: $LOCAL_HASH"
lap transfer

step "백업 → 교체 → 재시작 (백업: $BACKUP)"
# 서버에서 하는 일은 설정으로 바꿀 수 있다(기본: 단일 파일 + systemd). {tmp} {remote} {backup} {owner} {service} 를 채워 넣는다.
fill() { local t=$1; t=${t//\{tmp\}/$TMP}; t=${t//\{remote\}/$REMOTE}; t=${t//\{backup\}/$BACKUP}; t=${t//\{owner\}/$OWNER}; t=${t//\{service\}/$SERVICE}; echo "$t"; }
SWAP=$(fill "$(d swapCmd 'sudo cp -p {remote} {backup}; sudo install -o {owner} -g {owner} -m 644 {tmp} {remote}; rm -f {tmp}')")
RESTART=$(fill "$(d restartCmd 'sudo systemctl restart {service}')")
ROLLBACK=$(fill "$(d rollbackCmd 'sudo cp -p {backup} {remote} && sudo systemctl restart {service}')")
"${SSH[@]}" "set -e; $SWAP; $RESTART"
restart=$(date +%s)
lap swap

step "UP 대기 (최대 ${TIMEOUT}초): $HEALTH"
until curl -s -m 5 "$HEALTH" | grep -q '"UP"'; do
  sleep 5
  if [ $(( $(date +%s) - restart )) -gt "$TIMEOUT" ]; then
    echo "UP이 되지 않았습니다. 되돌리기: ssh $HOST '$ROLLBACK'" >&2
    exit 1
  fi
done
up=$(( $(date +%s) - restart )); echo "UP: 재시작 후 ${up}초"
lap up

step "배포 후 확인"
run_checks
lap checks
total=$(( $(date +%s) - start ))
write_log deploy "$up" "$total"
rp=$(jq -n --arg commit "$COMMIT" --arg subject "$SUBJECT" --arg hash "$LOCAL_HASH" --arg backup "$BACKUP" --arg host "$HOST" \
  --arg up "$up" --arg total "$total" --arg steps "${TIMES[*]:-}" --argjson rows "$CHECK_ROWS" --argjson failed "$failed" '
  {plugin:"devflow", kind:"deploy", title:"운영 배포 \($commit)", summary:"\($subject) — 전체 \($total)초, 재시작 후 \($up)초에 UP",
   env:"운영 서버 \($host)", status:(if $failed==1 then "fail" else "ok" end),
   sections:[
    {heading:"요약", kv:[["커밋",$commit],["해시(앞 16자)",$hash],["백업",$backup],["UP까지","\($up)초"],["전체","\($total)초"]]},
    {heading:"단계별 시간", bars:{unit:"초", items:[$steps|split(" ")[]|select(.!="")|split("=")|[.[0],(.[1]|tonumber)]]}},
    {heading:"배포 후 확인", table:{columns:["항목","결과"], rows:$rows}}]}' | report)
step "끝: 전체 ${total}초 (기록: $LOG, 리포트: $rp)"
exit $failed
