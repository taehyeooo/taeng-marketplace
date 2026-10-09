#!/usr/bin/env bash
# 측정을 N번 돌려 통계를 내고 레포 안 파일(결과 기록 + 표)로 남긴다. 고치기 전·후 비교, 기준값 대비 판정.
#   bench.sh list
#   bench.sh run <이름> [--label 이름표] [--runs N]   (예: --label before / after / 커밋 설명)
#   bench.sh compare <이름> [이름표A 이름표B]          (기본: 마지막 두 기록)
#   bench.sh baseline <이름|--tag 태그>                지금 값을 재서 기준값(이름표 baseline)으로
#   bench.sh check [--tag 태그] [--quiet]              재고 기준값과 비교 → 좋아짐/나빠짐/변화 없음/비교 불가, 나빠지면 알림
#   bench.sh collect usage [--since YYYY-MM-DD]        flow 플러그인 사용 로그를 플러그인·종류별로 센다(AI 도구 사용 지표)
#   bench.sh notify <제목> <내용>                       macOS 알림
# 설정 ~/.config/benchflow/<레포>.json: { resultsDir, benchmarks: { 이름: { description, env, cmd(한 번 실행에 숫자 하나 출력),
#   unit, runs, warmup, preCheck?, setup?, teardown?, better?(lower|higher), tolerance?("5%"|절대값), tags?[], entry? } } }
#   — 측정 대상·환경은 전부 설정에, 스크립트는 어떤 서비스든 같다. runs 1·warmup 0이면 한 번만 재는 값(정확도·개수 등).
set -euo pipefail
conf() { if [ -n "${BENCHFLOW_CONFIG:-}" ]; then echo "$BENCHFLOW_CONFIG"; return; fi
  local u n; u=$(git remote get-url origin 2>/dev/null || true); n=$(basename "${u%.git}"); echo "$HOME/.config/benchflow/${n:-$(basename "$PWD")}.json"; }
log() { mkdir -p "$HOME/.config/benchflow"; echo "$(date '+%F %T')	$1	${2:-}" >> "$HOME/.config/benchflow/usage.log"; }
notify() {  # 알림은 나빠짐·새 추천일 때만 부른다(호출하는 쪽이 판단)
  local t=${1//\"/\'} m=${2//\"/\'}
  osascript -e "display notification \"$m\" with title \"$t\"" >/dev/null 2>&1 || true; }
report() { local f; f=$(mktemp); cat > "$f"; python3 "$(dirname "${BASH_SOURCE[0]}")/report_html.py" "$f"; rm -f "$f"; }

case "${1:-}" in
notify) notify "${2:?제목}" "${3:-}"; exit 0 ;;
collect)
  [ "${2:-}" = usage ] || { echo "collect usage [--since YYYY-MM-DD]" >&2; exit 1; }
  since=""; [ "${3:-}" = --since ] && since=${4:-}
  python3 - "$since" <<'PY'
import glob, os, sys, collections
since = sys.argv[1]
counts = collections.Counter(); first, last = None, None
for f in sorted(glob.glob(os.path.expanduser("~/.config/*/usage.log"))):
    plugin = os.path.basename(os.path.dirname(f))
    for line in open(f, errors="ignore"):
        p = line.rstrip("\n").split("\t")
        if len(p) < 2 or not p[1] or (since and p[0] < since): continue
        counts[(plugin, p[1])] += 1; first = min(first or p[0], p[0]); last = max(last or p[0], p[0])
print(f"기간 {first} ~ {last}" if first else "기록 없음")
for plugin in sorted({k[0] for k in counts}):
    rows = sorted(((k[1], v) for k, v in counts.items() if k[0] == plugin), key=lambda x: -x[1])
    print(f"{plugin}\t합계 {sum(v for _, v in rows)}\t" + ", ".join(f"{k} {v}" for k, v in rows))
PY
  exit 0 ;;
esac

C=$(conf); [ -f "$C" ] || { echo "benchflow 설정이 없습니다: $C" >&2; exit 1; }
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
OUT="$ROOT/$(jq -r '.resultsDir // "docs/bench"' "$C")"
b() { jq -r --arg n "$1" ".benchmarks[\$n].$2 // empty" "$C"; }
names_for() {  # 태그가 붙은 측정 이름(태그 없으면 전부)
  if [ -n "${1:-}" ]; then jq -r --arg t "$1" '.benchmarks | to_entries[] | select((.value.tags // []) | index($t)) | .key' "$C"
  else jq -r '.benchmarks | keys[]' "$C"; fi; }
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
measure() {  # measure <이름> <이름표> [횟수] → 기록 한 줄 추가, 통계 JSON을 STATS에
  local n=$1 label=$2 runs=${3:-} cmd pre setup warm td v
  runs=${runs:-$(b "$n" runs)}; runs=${runs:-10}
  cmd=$(b "$n" cmd); [ -n "$cmd" ] || { echo "측정이 없습니다: $n" >&2; return 1; }
  pre=$(b "$n" preCheck); [ -n "$pre" ] && { echo "사전 확인: $(bash -c "$pre")" >&2; }
  setup=$(b "$n" setup); [ -n "$setup" ] && bash -c "$setup" >&2
  warm=$(b "$n" warmup); warm=${warm:-1}
  for _ in $(seq 1 "$warm"); do bash -c "$cmd" >/dev/null 2>&1 || true; done
  local vals=()
  for _ in $(seq 1 "$runs"); do v=$(bash -c "$cmd" | tail -1 | tr -d '[:space:]'); vals+=("$v"); printf '.' >&2; done; echo >&2
  td=$(b "$n" teardown); [ -n "$td" ] && bash -c "$td" >&2
  STATS=$(printf '%s\n' "${vals[@]}" | python3 -c '
import sys, statistics as st, json
xs = sorted(float(x) for x in sys.stdin if x.strip())
p90 = xs[min(len(xs) - 1, int(round(0.9 * (len(xs) - 1))))]
r = lambda v: round(v, 1) if abs(v) >= 1 else round(v, 4)
print(json.dumps({"n": len(xs), "median": r(st.median(xs)), "p90": r(p90), "min": r(xs[0]), "max": r(xs[-1]), "mean": r(st.mean(xs))}))')
  mkdir -p "$OUT"
  jq -nc --arg at "$(date '+%F %T')" --arg label "$label" --arg commit "$(git rev-parse --short HEAD 2>/dev/null || echo -)" \
    --arg env "$(b "$n" env)" --argjson stats "$STATS" --argjson vals "$(printf '%s\n' "${vals[@]}" | jq -R 'tonumber' | jq -sc .)" \
    '{at:$at, label:$label, commit:$commit, env:$env, stats:$stats, values:$vals}' >> "$OUT/$n.jsonl"
  render "$n"; log run "$n $label $(jq -c . <<< "$STATS")"
}

case "${1:-}" in
list) jq -r '.benchmarks | to_entries[] | "\(.key)\t\(.value.tags // [] | join(","))\t\(.value.description)"' "$C" ;;
run)
  n=${2:?측정 이름}; shift 2; label="run"; runs=""
  while [ $# -gt 0 ]; do case "$1" in --label) label=$2; shift 2 ;; --runs) runs=$2; shift 2 ;; *) shift ;; esac; done
  measure "$n" "$label" "$runs"; u=$(b "$n" unit)
  echo "$n [$label] $(jq -r '"중앙값 \(.median) · p90 \(.p90) · 최소 \(.min) · 최대 \(.max) · \(.n)회"' <<< "$STATS") $u — $OUT/$n.md"
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
baseline)
  if [ "${2:-}" = --tag ]; then names=$(names_for "${3:?태그}"); else names=${2:?측정 이름 또는 --tag 태그}; fi
  [ -n "$names" ] || { echo "해당 태그의 측정이 없습니다" >&2; exit 1; }
  for n in $names; do measure "$n" baseline; echo "$n 기준값: 중앙값 $(jq -r .median <<< "$STATS")$(b "$n" unit)"; done ;;
check)
  shift; tag=""; quiet=""
  while [ $# -gt 0 ]; do case "$1" in --tag) tag=$2; shift 2 ;; --quiet) quiet=1; shift ;; *) shift ;; esac; done
  names=$(names_for "$tag"); [ -n "$names" ] || { [ -n "$quiet" ] && exit 0; echo "${tag:+'$tag' 태그의 }측정이 없습니다" >&2; exit 1; }
  for n in $names; do measure "$n" check; done
  latest="$OUT/_check-latest.json"; echo "결과 폴더: $OUT"
  python3 - "$C" "$OUT" "$tag" "$(git rev-parse --short HEAD 2>/dev/null || echo -)" $names > "$latest" <<'PY'
import json, sys, datetime
conf, out, tag, commit, names = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:]
res = []
for n in names:
    m = conf["benchmarks"][n]; rows = [json.loads(l) for l in open(f"{out}/{n}.jsonl") if l.strip()]
    cur = rows[-1]; base = ([r for r in rows[:-1] if r["label"] == "baseline"] or [None])[-1]
    better = m.get("better", "lower"); tol = str(m.get("tolerance", "5%"))
    r = {"name": n, "description": m.get("description", ""), "unit": m.get("unit", ""), "better": better, "tolerance": tol,
         "entry": m.get("entry", ""), "current": {k: cur[k] for k in ("at", "commit", "env")} | {"median": cur["stats"]["median"], "p90": cur["stats"]["p90"], "n": cur["stats"]["n"]}}
    if base is None:
        r["verdict"] = "비교 불가"; r["reason"] = "기준값 없음 — baseline을 먼저"
    else:
        r["baseline"] = {k: base[k] for k in ("at", "commit", "env")} | {"median": base["stats"]["median"], "p90": base["stats"]["p90"], "n": base["stats"]["n"]}
        a, b = base["stats"]["median"], cur["stats"]["median"]; d = b - a
        r["deltaPct"] = round(d / a * 100, 1) if a else None
        if base["env"] != cur["env"]:
            r["verdict"] = "비교 불가"; r["reason"] = "환경이 다름"
        else:
            limit = abs(a) * float(tol[:-1]) / 100 if tol.endswith("%") else float(tol)
            if abs(d) <= limit: r["verdict"] = "변화 없음"
            else: r["verdict"] = "좋아짐" if (d < 0) == (better == "lower") else "나빠짐"
    res.append(r)
print(json.dumps({"at": f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}", "commit": commit, "tag": tag, "results": res}, ensure_ascii=False, indent=1))
PY
  jq -r '.results[] | "\(.verdict)\t\(.name)\t\(.baseline.median // "-") → \(.current.median)\(.unit)\(if .deltaPct then " (\(if .deltaPct > 0 then "+" else "" end)\(.deltaPct)%)" else "" end)\(if .reason then " — \(.reason)" else "" end)"' "$latest"
  bad=$(jq '[.results[] | select(.verdict == "나빠짐")] | length' "$latest")
  log check "${tag:-all} bad=$bad $(jq -r '[.results[] | "\(.name)=\(.verdict)"] | join(" ")' "$latest")"
  echo "리포트: $(jq --arg file "$latest" '
    def st: if ([.results[]|select(.verdict=="나빠짐")]|length) > 0 then "fail" elif ([.results[]|select(.verdict=="비교 불가")]|length) > 0 then "warn" else "ok" end;
    {plugin:"benchflow", kind:"check", title:"판정 — \(if .tag != "" then .tag else "전체" end) 지표 \(.results|length)개 (\(.commit))",
     summary:([.results[]|.verdict]|group_by(.)|map("\(.[0]) \(length)")|join(" · ")), env:(.results[0].current.env), status:st,
     sections:[{heading:"기준값 대비", table:{columns:["판정","지표","기준(중앙값)","지금(중앙값)","변화","허용 오차","좋은 방향"],
       rows:[.results[]|[.verdict,.name,"\(.baseline.median // "-")\(.unit) @\(.baseline.commit // "-")","\(.current.median)\(.unit) @\(.current.commit)",
             (if .deltaPct then "\(.deltaPct)%" else (.reason // "-") end),.tolerance,(if .better=="lower" then "낮을수록" else "높을수록" end)]]}},
       {heading:"다음", text:"나빠진 지표나 느린 지표는 Claude Code에서 /benchflow:advise 로 코드를 읽고 추천을 받는다. 판정 원본: \($file)"}]}' "$latest" | report)"
  if [ "$bad" -gt 0 ]; then
    notify "benchflow: 나빠진 지표 ${bad}개" "$(jq -r '[.results[]|select(.verdict=="나빠짐")|"\(.name) \(.baseline.median)→\(.current.median)\(.unit)"]|join(", ")' "$latest") — /benchflow:advise"
  fi ;;
*) sed -n '2,13p' "$0"; exit 1 ;;
esac
