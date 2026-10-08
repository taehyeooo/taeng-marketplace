#!/usr/bin/env bash
# 지금 띄운 화면을 글자 크기(와 선택적으로 다크 모드)별로 캡처해 한 장으로 붙인다.
#   sweep.sh <이름> [--dark]     설정의 기기(devices)마다, 글자 크기(textSizes)마다 캡처 → 한 장(기기별 한 줄)
# 끝나면 글자 크기·화면 모드를 원래대로 돌린다. 각 기기는 미리 같은 화면을 띄워 둔다.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
export UIFLOW_CONFIG=$(uiflow_config)
[ -f "$UIFLOW_CONFIG" ] || { echo "설정이 없습니다: $UIFLOW_CONFIG" >&2; exit 1; }
NAME=${1:?화면 이름}; DARK=0; [ "${2:-}" = "--dark" ] && DARK=1
OUT=$(expand "$(cfg .shotDir "$HOME/.config/uiflow/shots")"); mkdir -p "$OUT"
STAMP=$(date +%m%d-%H%M%S); WAIT=$(cfg .settleSeconds 3)
sizes=$(jq -r '.textSizes // ["large","extra-extra-extra-large","accessibility-extra-extra-extra-large"] | .[]' "$UIFLOW_CONFIG")
args=(); cols=$(printf '%s\n' "$sizes" | grep -c . ); [ "$DARK" = 1 ] && cols=$(( cols + 1 ))
while IFS=$'\t' read -r dname udid; do
  for size in $sizes; do
    xcrun simctl ui "$udid" content_size "$size"; sleep "$WAIT"
    f="$OUT/$STAMP-$NAME-$dname-$size.png"; xcrun simctl io "$udid" screenshot "$f" >/dev/null 2>&1
    args+=("$dname · $size" "$f")
  done
  if [ "$DARK" = 1 ]; then
    xcrun simctl ui "$udid" content_size large; xcrun simctl ui "$udid" appearance dark; sleep "$WAIT"
    f="$OUT/$STAMP-$NAME-$dname-dark.png"; xcrun simctl io "$udid" screenshot "$f" >/dev/null 2>&1
    args+=("$dname · dark" "$f"); xcrun simctl ui "$udid" appearance light
  fi
  xcrun simctl ui "$udid" content_size large
done < <(jq -r '.devices[] | [.name, .udid] | @tsv' "$UIFLOW_CONFIG")
sheet=$(python3 "$DIR/sheet.py" "$OUT/$STAMP-$NAME-sweep.png" "$cols" "${args[@]}")
log sweep "$NAME $(( ${#args[@]} / 2 ))장"
echo "훑기 완료($(( ${#args[@]} / 2 ))장 → 한 장): $sheet"
imgs=$(for ((k=0; k<${#args[@]}; k+=2)); do jq -nc --arg l "${args[k]}" --arg p "${args[k+1]}" '{label:$l, path:$p}'; done | jq -sc .)
echo "리포트: $(jq -n --arg n "$NAME" --arg sheet "$sheet" --argjson imgs "$imgs" '
  {plugin:"uiflow", kind:"sweep", title:"화면 훑기 — \($n)", summary:"글자 크기별 \($imgs|length)장 — 잘림·겹침·빈 요소를 확인", env:"iOS 시뮬레이터", status:"ok",
   sections:[{heading:"한 장으로 보기", images:[{label:"훑기 묶음", path:$sheet}]},{heading:"한 장씩", images:$imgs}]}' | report)"
