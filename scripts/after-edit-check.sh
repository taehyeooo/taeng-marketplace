#!/usr/bin/env bash
# PostToolUse 훅: 앱 화면 코드(.ts/.tsx 등)를 고친 직후 프로젝트 검사(타입 검사·디자인 토큰 검사 등)를 돌린다.
# 실패하면 exit 2로 Claude에게 결과를 돌려줘 바로 고치게 한다. 설정의 "checks"가 있는 레포에서만 동작.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null) || exit 0
source "$DIR/config.sh"
export UIFLOW_CONFIG=$(uiflow_config "$root")
[ -f "$UIFLOW_CONFIG" ] && jq -e '.checks' "$UIFLOW_CONFIG" >/dev/null 2>&1 || exit 0
pattern=$(cfg '.checkFiles' '\.(tsx?|jsx?)$')
printf '%s' "$file" | grep -Eq "$pattern" || exit 0
cd "$root"
fails=()
start=$(date +%s)
while IFS=$'\t' read -r name command; do
  [ -z "$name" ] && continue
  out=$(bash -c "$command" </dev/null 2>&1) || fails+=("[$name] $(printf '%s' "$out" | sed $'s/\x1b\\[[0-9;]*m//g' | tail -15)")
done < <(jq -r '.checks[] | [.name, .cmd] | @tsv' "$UIFLOW_CONFIG")
secs=$(( $(date +%s) - start ))
if [ ${#fails[@]} -gt 0 ]; then
  { echo "[uiflow] $(basename "$file") 수정 후 검사 실패:"; for f in "${fails[@]}"; do echo "$f"; done; } >&2
  log check-fail "$file ${secs}s"; exit 2
fi
log check-ok "$file ${secs}s"; exit 0
