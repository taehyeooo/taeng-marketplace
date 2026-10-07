#!/usr/bin/env bash
# 프로젝트 설정: ~/.config/uiflow/<origin 레포 이름>.json (UIFLOW_CONFIG로 바꿀 수 있음). 레포 밖에 두어 공개 레포에 올라가지 않게.
uiflow_config() {
  if [ -n "${UIFLOW_CONFIG:-}" ]; then echo "$UIFLOW_CONFIG"; return; fi
  local url name
  url=$(git -C "${1:-.}" remote get-url origin 2>/dev/null || true); name=$(basename "${url%.git}")
  [ -z "$name" ] && name=$(basename "$(git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null || pwd)")
  echo "$HOME/.config/uiflow/$name.json"
}
cfg() { local f; f=$(uiflow_config); [ -f "$f" ] || { echo "${2:-}"; return; }; local v; v=$(jq -r "$1 // empty" "$f"); echo "${v:-${2:-}}"; }
expand() { eval echo "$1"; }
log() { mkdir -p "$HOME/.config/uiflow"; echo "$(date '+%F %T')	$1	${2:-}" >> "$HOME/.config/uiflow/usage.log"; }
