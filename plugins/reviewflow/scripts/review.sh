#!/usr/bin/env bash
# PR 리뷰 재료 모으기 · 결과 기록 · (확인 후) PR 댓글.
#   review.sh collect [PR번호|브랜치]          변경분·변경 파일·커밋, 리뷰 대상 커밋의 규칙 문서(CLAUDE.md/AGENTS.md·docs/adr)를 실행 폴더에 모은다 → 폴더 경로 출력
#   review.sh record <실행 폴더>               <실행 폴더>/findings.json(심각도별 지적) → 사용 로그·HTML 리포트
#   review.sh comment <실행 폴더>              <실행 폴더>/comment.md를 PR 댓글 하나로 올린다(외부 게시 — 사용자 확인 후에만 부를 것)
# 설정 없음 — 어떤 레포든 같다. 기본 브랜치는 origin/HEAD.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMED="$HOME/.config/reviewflow"
log() { mkdir -p "$HOMED"; echo "$(date '+%F %T')	$1	${2:-}" >> "$HOMED/usage.log"; }
report() { local f; f=$(mktemp); cat > "$f"; python3 "$DIR/report_html.py" "$f"; rm -f "$f"; }
ROOT=$(git rev-parse --show-toplevel)
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#origin/##' || echo main)

case "${1:-}" in
collect)
  target=${2:-}; run="$HOMED/runs/$(basename "$ROOT")-$(date '+%Y%m%d-%H%M%S')"; mkdir -p "$run"
  git fetch -q origin "$BASE" 2>/dev/null || true
  if [[ "$target" =~ ^[0-9]+$ ]]; then
    gh pr view "$target" --json number,title,body,baseRefName,headRefName,headRefOid,url > "$run/pr.json"
    gh pr diff "$target" > "$run/diff.patch"
    gh pr diff "$target" --name-only > "$run/files.txt"
    gh pr view "$target" --json commits -q '.commits[] | "\(.oid[0:7]) \(.messageHeadline)"' > "$run/commits.txt"
    head=$(jq -r .headRefOid "$run/pr.json")
    git cat-file -e "$head" 2>/dev/null || git fetch -q origin "pull/$target/head" 2>/dev/null || true
  else
    ref=${target:-HEAD}; range="origin/$BASE...$ref"
    jq -n --arg b "$BASE" --arg h "$ref" '{number:null, title:null, baseRefName:$b, headRefName:$h}' > "$run/pr.json"
    git diff "$range" > "$run/diff.patch"; git diff --name-only "$range" > "$run/files.txt"
    git log --format='%h %s' "origin/$BASE..$ref" > "$run/commits.txt"
    head=$(git rev-parse "$ref")
  fi
  # 규칙 문서는 리뷰 대상 커밋 기준(체크아웃 상태와 무관) — 지침·ADR을 실행 폴더 rules/에 꺼내 둔다
  mkdir -p "$run/rules"; : > "$run/rules.txt"
  if git cat-file -e "$head" 2>/dev/null; then
    git ls-tree -r --name-only "$head" | grep -E '(^|/)(CLAUDE|AGENTS)\.md$|^docs/adr/.*\.md$' | grep -v '^\.claude/worktrees/' | while read -r pth; do
      mkdir -p "$run/rules/$(dirname "$pth")"; git show "$head:$pth" > "$run/rules/$pth"; echo "$run/rules/$pth" >> "$run/rules.txt"; done
  else
    for pth in CLAUDE.md AGENTS.md; do if [ -f "$ROOT/$pth" ]; then echo "$ROOT/$pth" >> "$run/rules.txt"; fi; done
    if [ -d "$ROOT/docs/adr" ]; then find "$ROOT/docs/adr" -name '*.md' | sort >> "$run/rules.txt"; fi
  fi
  jq -n --arg root "$ROOT" --arg head "$head" --arg at "$(date '+%F %T')" --argjson start "$(date +%s)" \
    --argjson files "$(wc -l < "$run/files.txt" | tr -d ' ')" --argjson lines "$(grep -cE '^[+-][^+-]' "$run/diff.patch" || true)" \
    '{root:$root, head:$head, at:$at, start:$start, files:$files, changedLines:$lines}' > "$run/meta.json"
  log collect "$(basename "$run") files=$(jq .files "$run/meta.json") lines=$(jq .changedLines "$run/meta.json")"
  echo "$run" ;;
record)
  run=${2:?실행 폴더}; f="$run/findings.json"; [ -f "$f" ] || { echo "findings.json이 없습니다: $f" >&2; exit 1; }
  secs=$(( $(date +%s) - $(jq .start "$run/meta.json") ))
  counts=$(jq -c '[.findings[] | .severity] | group_by(.) | map({(.[0]): length}) | add // {}' "$f")
  log review "$(basename "$run") secs=$secs dropped=$(jq '.dropped // 0' "$f") $counts"
  echo "리포트: $(jq --slurpfile pr "$run/pr.json" --slurpfile m "$run/meta.json" --arg secs "$secs" --argjson c "$counts" '
    ($pr[0]) as $p | ($m[0]) as $mm |
    {plugin:"reviewflow", kind:"review", title:"리뷰 — \(if $p.number then "PR #\($p.number) \($p.title)" else $p.headRefName end)",
     summary:("지적 \(.findings|length)건" + (if ($c|length) > 0 then " (" + ([$c|to_entries[]|"\(.key) \(.value)"]|join(" · ")) + ")" else "" end) + " · 검증에서 뺀 것 \(.dropped // 0)건 · \($secs)초"),
     env:"로컬 Claude Code(구독 안의 에이전트)",
     status:(if ([.findings[]|select(.severity=="높음")]|length) > 0 then "fail" elif (.findings|length) > 0 then "warn" else "ok" end),
     sections:[{heading:"범위", kv:[["대상",(if $p.number then ($p.url // "PR #\($p.number)") else "\($p.headRefName) vs \($p.baseRefName)" end)],["변경 파일","\($mm.files)개"],["변경 줄","\($mm.changedLines)줄"],["걸린 시간","\($secs)초"]]},
       {heading:"지적(심각도 순)", table:{columns:["심각도","관점","위치","내용","실패 시나리오"], rows:[.findings[]|[.severity,.lens,.location,.summary,(.scenario // "")]]}}]}' "$f" | report)" ;;
comment)
  run=${2:?실행 폴더}; n=$(jq -r '.number // empty' "$run/pr.json"); [ -n "$n" ] || { echo "PR 번호가 없는 리뷰입니다" >&2; exit 1; }
  [ -f "$run/comment.md" ] || { echo "comment.md가 없습니다" >&2; exit 1; }
  gh pr comment "$n" --body-file "$run/comment.md"; log comment "#$n" ;;
*) sed -n '2,6p' "$0"; exit 1 ;;
esac
