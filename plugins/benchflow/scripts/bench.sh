#!/usr/bin/env bash
# 측정을 N번 돌려 통계를 내고 레포 안 파일(결과 기록 + 표)로 남긴다. 고치기 전·후 비교.
#   bench.sh list
#   bench.sh run <이름> [--label 이름표] [--runs N]   (예: --label before / after / 커밋 설명)
#   bench.sh compare <이름> [이름표A 이름표B]          (기본: 마지막 두 기록)
# 설정 ~/.config/benchflow/<레포>.json: { resultsDir, benchmarks: { 이름: { description, env, cmd(한 번 실행에 숫자 하나 출력),
#   unit, runs, warmup, preCheck?, setup?, teardown? } } } — 측정 대상·환경은 전부 설정에, 스크립트는 어떤 서비스든 같다.
set -euo pipefail
conf() { if [ -n "${BENCHFLOW_CONFIG:-}" ]; then echo "$BENCHFLOW_CONFIG"; return; fi
  local u n; u=$(git remote get-url origin 2>/dev/null || true); n=$(basename "${u%.git}"); echo "$HOME/.config/benchflow/${n:-$(basename "$PWD")}.json"; }
C=$(conf); [ -f "$C" ] || { echo "benchflow 설정이 없습니다: $C" >&2; exit 1; }
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
OUT="$ROOT/$(jq -r '.resultsDir // "docs/bench"' "$C")"
b() { jq -r --arg n "$1" ".benchmarks[\$n].$2 // empty" "$C"; }
log() { mkdir -p "$HOME/.config/benchflow"; echo "$(date '+%F %T')	$1	${2:-}" >> "$HOME/.config/benchflow/usage.log"; }
report() { local f; f=$(mktemp); cat > "$f"; python3 "$(dirname "${BASH_SOURCE[0]}")/report_html.py" "$f"; rm -f "$f"; }
render() {  # 결과 기록(jsonl) → 사람이 읽는 표(md)
  local n=$1; python3 - "$OUT/$n.jsonl" "$OUT/$n.md" "$n" "$(b "$n" description)" "$(b "$n" unit)" <<'PY'
import json, sys
src, dst, name, desc, unit = sys.argv[1:6]
rows = [json.loads(l) for l in open(src) if l.strip()]
lines = [f"# {name}", "", desc, "", f"단위: {unit}. 같은 측정을 여러 번 돌린 통계(워밍업 제외). 새 기록이 위.", "",
         "| 측정 시각 | 이름표 | 커밋 | 환경 | 횟수 | 중앙값 | p90 | 최소 | 최대 |", "|---|---|---|---|---|---|---|---|---|"]
for r in reversed(rows):
    s = r["stats"]
    lines.append(f"| {r['at']} | {r['label']} | `{r['commit']}` | {r['env']} | {s['n']} | {s['median']} | {s['p90']} | {s['min']} | {s['max']} |")
open(dst, "w").write("\n".join(lines) + "\n")
PY
}
case "${1:-}" in
list) jq -r '.benchmarks | to_entries[] | "\(.key)\t\(.value.description)"' "$C" ;;
run)
  n=${2:?측정 이름}; shift 2; label="run"; runs=$(b "$n" runs); runs=${runs:-10}
  while [ $# -gt 0 ]; do case "$1" in --label) label=$2; shift 2 ;; --runs) runs=$2; shift 2 ;; *) shift ;; esac; done
  cmd=$(b "$n" cmd); [ -n "$cmd" ] || { echo "측정이 없습니다: $n" >&2; exit 1; }
  pre=$(b "$n" preCheck); [ -n "$pre" ] && { echo "사전 확인: $(bash -c "$pre")"; }
  setup=$(b "$n" setup); [ -n "$setup" ] && bash -c "$setup"
  warm=$(b "$n" warmup); warm=${warm:-1}
  for _ in $(seq 1 "$warm"); do bash -c "$cmd" >/dev/null 2>&1 || true; done
  vals=()
  for i in $(seq 1 "$runs"); do v=$(bash -c "$cmd" | tail -1 | tr -d '[:space:]'); vals+=("$v"); printf '.'; done; echo
  td=$(b "$n" teardown); [ -n "$td" ] && bash -c "$td"
  stats=$(printf '%s\n' "${vals[@]}" | python3 -c '
import sys, statistics as st, json
xs = sorted(float(x) for x in sys.stdin if x.strip())
p90 = xs[min(len(xs) - 1, int(round(0.9 * (len(xs) - 1))))]
r = lambda v: round(v, 1)
print(json.dumps({"n": len(xs), "median": r(st.median(xs)), "p90": r(p90), "min": r(xs[0]), "max": r(xs[-1]), "mean": r(st.mean(xs))}))')
  mkdir -p "$OUT"
  jq -nc --arg at "$(date '+%F %T')" --arg label "$label" --arg commit "$(git rev-parse --short HEAD 2>/dev/null || echo -)" \
    --arg env "$(b "$n" env)" --argjson stats "$stats" --argjson vals "$(printf '%s\n' "${vals[@]}" | jq -R 'tonumber' | jq -sc .)" \
    '{at:$at, label:$label, commit:$commit, env:$env, stats:$stats, values:$vals}' >> "$OUT/$n.jsonl"
  render "$n"; log run "$n $label $(jq -c . <<< "$stats")"
  echo "$n [$label] $(jq -r '"중앙값 \(.median) · p90 \(.p90) · 최소 \(.min) · 최대 \(.max) · \(.n)회"' <<< "$stats") $(b "$n" unit) — $OUT/$n.md"
  u=$(b "$n" unit)
  echo "리포트: $(tail -n 8 "$OUT/$n.jsonl" | jq -s --arg n "$n" --arg u "$u" --arg d "$(b "$n" description)" --arg file "$OUT/$n.md" '
    (last) as $r | {plugin:"benchflow", kind:"bench", title:"측정 — \($n) [\($r.label)]", summary:"중앙값 \($r.stats.median)\($u) · p90 \($r.stats.p90)\($u) · \($r.stats.n)회", env:$r.env, status:"ok",
     sections:[{heading:"이번 측정", kv:[["설명",$d],["커밋",$r.commit],["중앙값","\($r.stats.median)\($u)"],["p90","\($r.stats.p90)\($u)"],["최소~최대","\($r.stats.min)~\($r.stats.max)\($u)"],["기록 파일",$file]]},
               {heading:"회차별 값", bars:{unit:$u, items:[$r.values|to_entries[]|["\(.key+1)회",.value]]}},
               {heading:"최근 기록 중앙값", bars:{unit:$u, highlight:"\($r.label) \($r.at[5:16])", items:[.[]|["\(.label) \(.at[5:16])",.stats.median]]}}]}' | report)" ;;
compare)
  n=${2:?측정 이름}; f="$OUT/$n.jsonl"; [ -f "$f" ] || { echo "기록이 없습니다: $f" >&2; exit 1; }
  python3 - "$f" "${3:-}" "${4:-}" "$(b "$n" unit)" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
la, lb, unit = sys.argv[2], sys.argv[3], sys.argv[4]
pick = lambda l: [r for r in rows if r["label"] == l][-1]
a, b = (pick(la), pick(lb)) if la and lb else (rows[-2], rows[-1])
ma, mb = a["stats"]["median"], b["stats"]["median"]
d = (mb - ma) / ma * 100 if ma else 0
print(f"{a['label']}({a['commit']}) 중앙값 {ma}{unit} → {b['label']}({b['commit']}) {mb}{unit}: {d:+.1f}%")
print(f"p90 {a['stats']['p90']} → {b['stats']['p90']}, 환경: {a['env']} / {b['env']}")
if a["env"] != b["env"]: print("주의: 두 기록의 환경이 다릅니다 — 비교에 쓰지 마세요")
PY
  ;;
*) sed -n '2,8p' "$0"; exit 1 ;;
esac
