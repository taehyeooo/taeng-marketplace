#!/usr/bin/env bash
# PreToolUse(Bash) 훅: Claude가 `git commit`을 실행하기 직전에 프로젝트 규칙을 확인하고, 어기면 막는다(exit 2).
#  1) 커밋 메시지 형식(예: "feat: 내용")
#  2) AI 서명·트레일러 금지(Co-Authored-By: Claude, Generated with Claude Code, 🤖)
#  3) 스테이징된 변경에 넣으면 안 되는 문자열(예: 임시 QA 토큰 패치 QA_TOKEN)
# 프로젝트 설정(~/.config/devflow/<레포>.json)의 "commit"이 있을 때만 동작한다 — 규칙은 프로젝트마다 다르니까.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
case "$cmd" in *"git commit"*|*"git -C "*" commit"*) ;; *) exit 0 ;; esac

# `cd 경로 && git commit ...` 이나 `git -C 경로 commit` 이면 그 경로의 레포를 본다.
repo=$(printf '%s' "$cmd" | sed -nE 's/.*git -C ("[^"]+"|[^ ]+) commit.*/\1/p' | tr -d '"')
[ -z "$repo" ] && repo=$(printf '%s' "$cmd" | sed -nE 's/^cd ("[^"]+"|[^ &;]+) *(&&|;).*/\1/p' | tr -d '"')
repo=${repo/#\~/$HOME}
[ -n "$repo" ] && [ -d "$repo" ] && cd "$repo"
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

source "$DIR/config.sh"
conf=$(devflow_config)
[ -f "$conf" ] && jq -e '.commit' "$conf" >/dev/null 2>&1 || exit 0

problems=()

# 1) 메시지 형식 — -m "..." / -m '...' / -m "$(cat <<'EOF' ... )" 의 첫 줄
msg=$(printf '%s' "$cmd" | python3 -c '
import re, sys
c = sys.stdin.read()
heredoc = re.search(r"-m\s+\"\$\(cat\s+<<\W*EOF\W*\n(.*?)\n", c, re.S)
quoted = re.search(r"-m\s+([\"\x27])(.*?)\1", c, re.S)
text = heredoc.group(1) if heredoc else (quoted.group(2) if quoted else "")
print(text.splitlines()[0] if text else "")
')
pattern=$(jq -r '.commit.messagePattern // "^(feat|fix|docs|style|refactor|chore|perf|test): .+"' "$conf")
if [ -n "$msg" ] && ! printf '%s' "$msg" | grep -Eq "$pattern"; then
  problems+=("커밋 메시지 형식이 규칙과 다릅니다: \"$msg\" (규칙: $pattern)")
fi

# 2) AI 서명·트레일러
if [ "$(jq -r '.commit.forbidAiTrailer // true' "$conf")" = "true" ]; then
  if printf '%s' "$cmd" | grep -Eiq 'Co-Authored-By:.*(Claude|anthropic)|Generated with \[?Claude|🤖'; then
    problems+=("커밋에 AI 서명·트레일러가 들어 있습니다(Co-Authored-By: Claude / Generated with Claude Code / 🤖). 이 프로젝트는 사용자만 작성자로 남깁니다.")
  fi
fi

# 3) 스테이징된 변경의 금지 문자열 — `commit -a`면 추적 중인 파일의 변경도 같이 본다
added=$(git diff --cached -U0 2>/dev/null | grep '^+' | grep -v '^+++')
if printf '%s' "$cmd" | grep -Eq 'commit( [^|;&]*)? (-a|--all|-am)'; then
  added+=$'\n'$(git diff -U0 2>/dev/null | grep '^+' | grep -v '^+++')
fi
while IFS= read -r pat; do
  [ -z "$pat" ] && continue
  if printf '%s' "$added" | grep -Eq "$pat"; then
    files=$( { git diff --cached -G"$pat" --name-only; git diff -G"$pat" --name-only; } 2>/dev/null | sort -u | tr '\n' ' ')
    problems+=("커밋하면 안 되는 내용이 변경에 있습니다: /$pat/ (파일: ${files:-확인 필요}). 임시 패치라면 되돌리고 필요한 파일만 경로로 스테이징하세요.")
  fi
done < <(jq -r '.commit.forbiddenStaged[]? // empty' "$conf")

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "[devflow commit-guard] 커밋을 막았습니다:"
    for p in "${problems[@]}"; do echo " - $p"; done
  } >&2
  echo "$(date '+%F %T')	blocked	$(git rev-parse --show-toplevel)	${problems[*]}" >> "$HOME/.config/devflow/usage.log"
  exit 2
fi
echo "$(date '+%F %T')	commit-ok	$(git rev-parse --show-toplevel)	$msg" >> "$HOME/.config/devflow/usage.log"
exit 0
