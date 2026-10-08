#!/usr/bin/env bash
# 프로젝트 설정 찾기: 서버 주소·키 경로 같은 값은 공개 레포에 올리지 않게 레포 밖에 둔다.
#   DEVFLOW_CONFIG가 있으면 그 파일, 없으면 ~/.config/devflow/<origin 레포 이름>.json
# worktree에서도 같은 설정을 쓰도록 폴더 이름이 아니라 origin 주소에서 레포 이름을 뽑는다.
devflow_config() {
  if [ -n "${DEVFLOW_CONFIG:-}" ]; then echo "$DEVFLOW_CONFIG"; return; fi
  local url name
  url=$(git remote get-url origin 2>/dev/null || true)
  name=$(basename "${url%.git}")
  [ -z "$name" ] && name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
  echo "$HOME/.config/devflow/$name.json"
}
# cfg <jq 경로> [기본값]
cfg() {
  local f; f=$(devflow_config)
  [ -f "$f" ] || { [ -n "${2:-}" ] && echo "$2"; return; }
  local v; v=$(jq -r "$1 // empty" "$f")
  if [ -z "$v" ]; then echo "${2:-}"; else echo "$v"; fi
}
expand() { eval echo "$1"; }  # ~ 와 $HOME 펼치기
# 사용 기록 한 줄(macOS 기본 명령 `log`와 이름이 겹치지 않게 함수로 덮어쓴다)
log() { mkdir -p "$HOME/.config/devflow"; echo "$(date '+%F %T')	$1	${2:-}" >> "$HOME/.config/devflow/usage.log"; }
# HTML 리포트: JSON을 받아 ~/.config/flow-reports/에 만들고 경로를 출력(목록 페이지 index.html도 갱신)
report() { local f; f=$(mktemp); cat > "$f"; python3 "$(dirname "${BASH_SOURCE[0]}")/report_html.py" "$f"; rm -f "$f"; }
