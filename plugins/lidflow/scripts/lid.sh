#!/usr/bin/env bash
# lidflow — 노트북 덮개를 닫아도 잠들지 않게 켜고/끄고/확인한다.
#   bash lid.sh on | off | status
# macOS: pmset disablesleep (관리자 비밀번호 창으로 받음 — TTY 없는 세션에서도 동작)
# Windows(Git Bash/MSYS): powercfg 덮개 닫기 동작(LIDACTION). 켜기 전 값을 저장해 끌 때 되돌린다.
# 상태 줄 첫 단어는 ON / OFF / UNSUPPORTED 로 고정한다(스킬이 이걸로 판단).
set -euo pipefail

cmd="${1:-status}"
state_dir="${LIDFLOW_STATE_DIR:-$HOME/.config/lidflow}"

mac_status() {
  if pmset -g | grep -Eq 'SleepDisabled[[:space:]]+1'; then
    echo "ON macOS SleepDisabled=1 — 덮개를 닫아도 안 잠듦. 가방에 넣기 전에 끌 것"
  else
    echo "OFF macOS SleepDisabled=0 — 기본값, 덮개를 닫으면 잠듦"
  fi
}

mac_set() {
  # 비밀번호 창을 취소하면 osascript가 실패한다 → set -e로 멈춤
  osascript -e "do shell script \"/usr/bin/pmset -a disablesleep $1\" with administrator privileges" >/dev/null
  mac_status
}

# powercfg /q 출력은 Windows 언어마다 문구가 달라서, 마지막 두 0x 값(AC, DC 순)만 읽는다.
win_values() {
  powercfg.exe /q SCHEME_CURRENT SUB_BUTTONS LIDACTION | tr -d '\r' \
    | grep -Eo '0x[0-9a-fA-F]{8}' | tail -2 | tr '\n' ' '
}

win_status() {
  read -r ac dc <<<"$(win_values)"
  if [[ "$((ac))" == 0 && "$((dc))" == 0 ]]; then
    echo "ON Windows LIDACTION AC=$((ac)) DC=$((dc)) — 덮개를 닫아도 아무것도 안 함. 가방에 넣기 전에 끌 것"
  else
    echo "OFF Windows LIDACTION AC=$((ac)) DC=$((dc)) — 덮개를 닫으면 절전/최대절전 등(0=아무것도 안 함, 1=절전, 2=최대절전, 3=종료)"
  fi
}

win_apply() {
  powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION "$1"
  powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION "$2"
  powercfg.exe /setactive SCHEME_CURRENT
}

win_on() {
  mkdir -p "$state_dir"
  read -r ac dc <<<"$(win_values)"
  # 이미 켜진 상태에서 다시 켜면 저장값(원래 값)을 덮어쓰지 않는다
  if [[ ! ( "$((ac))" == 0 && "$((dc))" == 0 ) ]]; then
    echo "$((ac)) $((dc))" >"$state_dir/windows-lidaction"
  fi
  win_apply 0 0
  win_status
}

win_off() {
  local ac=1 dc=1
  if [[ -f "$state_dir/windows-lidaction" ]]; then
    read -r ac dc <"$state_dir/windows-lidaction"
  fi
  win_apply "$ac" "$dc"
  rm -f "$state_dir/windows-lidaction"
  win_status
}

case "$(uname -s)" in
  Darwin)
    case "$cmd" in
      on) mac_set 1 ;;
      off) mac_set 0 ;;
      status) mac_status ;;
      *) echo "사용법: lid.sh on|off|status" >&2; exit 2 ;;
    esac ;;
  MINGW* | MSYS* | CYGWIN*)
    case "$cmd" in
      on) win_on ;;
      off) win_off ;;
      status) win_status ;;
      *) echo "사용법: lid.sh on|off|status" >&2; exit 2 ;;
    esac ;;
  *)
    echo "UNSUPPORTED $(uname -s) — 지원: macOS, Windows(Git Bash). Linux는 /etc/systemd/logind.conf의 HandleLidSwitch로 직접 설정"
    exit 3 ;;
esac
