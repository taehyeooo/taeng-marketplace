#!/usr/bin/env bash
# 이슈 → 브랜치/작업 폴더 → PR → 머지 → 정리를 규칙대로.
#   ship.sh start <타입> <영문-슬러그> "<제목>" ["<이슈 본문>"]   이슈 만들고 규칙대로 브랜치 + worktree(원격 기본 브랜치에서)
#   ship.sh pr ["<PR 본문 추가 문장>"]                              (작업 폴더에서) 빌드·테스트 → 푸시 → "Closes #N" PR
#   ship.sh merge [PR 번호]                                        머지(설정 방식) → 이슈 닫힘 확인 → worktree 정리 → 후속 명령
# 설정 "ship": branchPattern("{type}/#{issue}-{slug}"), worktreeDir, build, mergeMethod, prFooter, afterMerge
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/config.sh"
export DEVFLOW_CONFIG="$(devflow_config)"
s() { cfg ".ship.$1" "${2:-}"; }
ROOT=$(git rev-parse --show-toplevel); MAIN_ROOT=$(git worktree list --porcelain | awk 'NR==1{print $2}')
BASE=$(s baseBranch "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#origin/##' || echo main)")
case "${1:-}" in
start)
  type=${2:?타입(feat/fix/docs…)}; slug=${3:?영문 슬러그}; title=${4:?제목}; body=${5:-}
  url=$(gh issue create --title "$type: $title" --body "${body:-$title}"); issue=${url##*/}
  branch=$(s branchPattern '{type}/#{issue}-{slug}'); branch=${branch//\{type\}/$type}; branch=${branch//\{issue\}/$issue}; branch=${branch//\{slug\}/$slug}
  wt="$MAIN_ROOT/$(s worktreeDir .claude/worktrees)/$slug"
  git -C "$MAIN_ROOT" fetch -q origin && git -C "$MAIN_ROOT" worktree add -q "$wt" -b "$branch" "origin/$BASE"
  log ship-start "#$issue $branch"; echo "이슈 #$issue: $url"; echo "브랜치 $branch"; echo "작업 폴더 $wt" ;;
pr)
  branch=$(git branch --show-current); issue=$(printf '%s' "$branch" | grep -oE '#[0-9]+' | tr -d '#')
  [ -n "$issue" ] || { echo "브랜치 이름에서 이슈 번호를 찾지 못했습니다: $branch" >&2; exit 1; }
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "커밋하지 않은 변경이 있습니다" >&2; exit 1; }
  BUILD=$(s build); t0=$(date +%s)
  if [ -n "$BUILD" ]; then echo "빌드·테스트: $BUILD"; bash -c "$BUILD"; fi
  tests=""
  if ls build/test-results/test/*.xml >/dev/null 2>&1; then
    tests="테스트 $(grep -ho '<testcase ' build/test-results/test/*.xml | wc -l | tr -d ' ')개 통과(로컬)"
  fi
  git push -q -u origin "$branch"
  title=$(gh issue view "$issue" --json title -q .title)
  body="$(git log --format='- %s' "origin/$BASE"..HEAD)
${2:+
$2
}${tests:+
$tests
}
Closes #$issue$(s prFooter)"
  url=$(gh pr create --base "$BASE" --head "$branch" --title "$title" --body "$body")
  log ship-pr "#$issue $url build=$(( $(date +%s) - t0 ))s"; echo "PR: $url"
  echo "리포트: $(jq -n --arg i "$issue" --arg b "$branch" --arg u "$url" --arg t "${tests:-빌드 결과 없음}" --arg s "$(( $(date +%s) - t0 ))" --arg c "$(git log --format='%h %s' "origin/$BASE"..HEAD)" '
    {plugin:"devflow", kind:"ship-pr", title:"PR 만듦 #\($i)", summary:"\($u)", env:"로컬 빌드·테스트", status:"ok",
     sections:[{heading:"요약", kv:[["이슈","#\($i)"],["브랜치",$b],["PR",$u],["테스트",$t],["빌드·푸시·PR까지","\($s)초"]]},{heading:"커밋", text:$c}]}' | report)" ;;
merge)
  pr=${2:-$(gh pr view --json number -q .number)}
  info=$(gh pr view "$pr" --json title,headRefName,body); title=$(jq -r .title <<< "$info"); head=$(jq -r .headRefName <<< "$info")
  method=$(s mergeMethod squash)
  gh pr merge "$pr" "--$method" --subject "$title (#$pr)" --body "" --delete-branch=false
  git -C "$MAIN_ROOT" fetch -q origin
  for n in $(jq -r .body <<< "$info" | grep -oiE '(closes|fixes) #[0-9]+' | grep -oE '[0-9]+'); do
    st=$(gh issue view "$n" --json state -q .state); [ "$st" = CLOSED ] || { gh issue close "$n" -c "#$pr 머지로 완료" >/dev/null; st="CLOSED(직접 닫음)"; }
    echo "이슈 #$n: $st"
  done
  wt=$(git -C "$MAIN_ROOT" worktree list --porcelain | awk -v b="refs/heads/$head" '/^worktree /{w=$2} $0=="branch "b{print w}')
  if [ -n "$wt" ]; then
    ignored=$(git -C "$wt" status --porcelain --ignored | grep '^!!' | grep -vE 'build/|node_modules/|\.gradle/|\.superpowers/' || true)
    if [ -n "$(git -C "$wt" status --porcelain)" ] || [ -n "$ignored" ]; then
      echo "작업 폴더에 남은 파일이 있어 지우지 않았습니다: $wt"; printf '%s\n' "$ignored" | head -5
    else git -C "$MAIN_ROOT" worktree remove --force "$wt"; echo "작업 폴더 정리: $wt"; fi
  fi
  after=$(s afterMerge); [ -n "$after" ] && { echo "후속: $after"; bash -c "$after"; }
  log ship-merge "#$pr $title"; echo "머지 완료: $title (#$pr)"
  echo "리포트: $(jq -n --arg pr "$pr" --arg t "$title" --arg wt "${wt:-없음}" --arg after "${after:-없음}" --arg head "$(git -C "$MAIN_ROOT" log --oneline -1 "origin/$BASE")" '
    {plugin:"devflow", kind:"ship-merge", title:"머지 #\($pr)", summary:$t, env:"GitHub + 로컬", status:"ok",
     sections:[{heading:"요약", kv:[["PR","#\($pr)"],["기본 브랜치 최신",$head],["작업 폴더",$wt],["후속 명령",$after]]}]}' | report)" ;;
*) sed -n '2,7p' "$0"; exit 1 ;;
esac
