#!/usr/bin/env bash
# 고치기 전·후 비교 이미지: 같은 화면을 고치기 전에 한 번, 고친 뒤에 한 번 캡처해 나란히 붙인다.
#   compare.sh before <이름>   지금 화면을 "고치기 전"으로 저장
#   compare.sh after <이름>    지금 화면을 "고친 뒤"로 캡처하고 둘을 한 장으로
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
export UIFLOW_CONFIG=$(uiflow_config)
[ -f "$UIFLOW_CONFIG" ] || { echo "설정이 없습니다: $UIFLOW_CONFIG" >&2; exit 1; }
MODE=${1:?before|after}; NAME=${2:?화면 이름}
UDID=$(jq -r '.devices[0].udid' "$UIFLOW_CONFIG")
OUT=$(expand "$(cfg .shotDir "$HOME/.config/uiflow/shots")"); mkdir -p "$OUT" "$HOME/.config/uiflow/state"
B="$HOME/.config/uiflow/state/$NAME-before.png"
case "$MODE" in
before) xcrun simctl io "$UDID" screenshot "$B" >/dev/null 2>&1; log compare-before "$NAME"; echo "고치기 전 저장: $B" ;;
after)
  [ -f "$B" ] || { echo "먼저 compare.sh before $NAME" >&2; exit 1; }
  A="$OUT/$(date +%m%d-%H%M%S)-$NAME-after.png"; xcrun simctl io "$UDID" screenshot "$A" >/dev/null 2>&1
  sheet=$(python3 "$DIR/sheet.py" "$OUT/$(date +%m%d-%H%M%S)-$NAME-compare.png" 2 "고치기 전" "$B" "고친 뒤" "$A")
  log compare "$NAME"; echo "비교 이미지: $sheet" ;;
*) sed -n '2,4p' "$0"; exit 1 ;;
esac
