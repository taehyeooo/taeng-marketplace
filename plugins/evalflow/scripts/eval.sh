#!/usr/bin/env bash
# AI 출력 정확도를 promptfoo로 같은 방식으로 채점하고 레포 안 파일로 남긴다. 고치기 전·후 비교, 새로 틀린 케이스 찾기.
#   eval.sh list
#   eval.sh count <이름> [--filter 정규식] [--first N]            예상 호출 수(시험 수 × 프롬프트 × 제공자 × callsPerTest)
#   eval.sh run <이름> [--label 이름표] [--filter 정규식] [--first N] [--yes]
#   eval.sh diff <이름> [이름표A 이름표B]                         새로 틀린/새로 맞힌 케이스(기본: 마지막 두 기록)
# 설정 ~/.config/evalflow/<레포>.json: { resultsDir?("docs/eval"), promptfooVersion?, suites: { 이름: { description, env,
#   config(레포 기준 promptfoo 설정 경로), metrics?[namedScores 중 기록할 것], preCheck?, maxCalls?, callsPerTest?, delayMs?,
#   maxConcurrency?, envFile? } } } — 평가 대상·정답은 각 서비스 레포에, 스크립트는 어떤 서비스든 같다.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
conf() { if [ -n "${EVALFLOW_CONFIG:-}" ]; then echo "$EVALFLOW_CONFIG"; return; fi
  local u n; u=$(git remote get-url origin 2>/dev/null || true); n=$(basename "${u%.git}"); echo "$HOME/.config/evalflow/${n:-$(basename "$PWD")}.json"; }
log() { mkdir -p "$HOME/.config/evalflow"; echo "$(date '+%F %T')	$1	${2:-}" >> "$HOME/.config/evalflow/usage.log"; }
notify() { local t=${1//\"/\'} m=${2//\"/\'}; osascript -e "display notification \"$m\" with title \"$t\"" >/dev/null 2>&1 || true; }
report() { local f; f=$(mktemp); cat > "$f"; python3 "$DIR/report_html.py" "$f"; rm -f "$f"; }
C=$(conf); [ -f "$C" ] || { echo "evalflow 설정이 없습니다: $C" >&2; exit 1; }
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
OUT="$ROOT/$(jq -r '.resultsDir // "docs/eval"' "$C")"
PF="promptfoo@$(jq -r '.promptfooVersion // "0.123.1"' "$C")"
s() { jq -r --arg n "$1" ".suites[\$n].$2 // empty" "$C"; }
export PROMPTFOO_DISABLE_TELEMETRY=1 PROMPTFOO_DISABLE_UPDATE=1 PROMPTFOO_DISABLE_SHARING=1

count() {  # count <설정 경로> <filter> <first> <callsPerTest> → 예상 호출 수
  ruby -ryaml -rcsv -e '
    cfg_path, pat, first, per = ARGV; base = File.dirname(cfg_path); cfg = YAML.load_file(cfg_path)
    load = ->(t) { t = t.sub(%r{\Afile://}, ""); p = File.join(base, t)
      p.end_with?(".csv") ? CSV.read(p, headers: true).map(&:to_h) : Array(YAML.load_file(p)) }
    tests = Array(cfg["tests"]).flat_map { |t| t.is_a?(String) ? load.(t) : [t] }
    tests = tests.select { |t| (t["description"] || "") =~ Regexp.new(pat) } unless pat.empty?
    tests = tests.first(first.to_i) unless first.empty?
    n = [Array(cfg["prompts"]).size, 1].max * [Array(cfg["providers"]).size, 1].max * (per.empty? ? 1 : per.to_i)
    puts "#{tests.size}\t#{tests.size * n}"' "$1" "$2" "$3" "$4"
}

case "${1:-}" in
list) jq -r '.suites | to_entries[] | "\(.key)\t\(.value.description // "")"' "$C" ;;
count|run)
  cmd=$1; n=${2:?평가 이름}; shift 2; label="run"; filter=""; first=""; yes=""
  while [ $# -gt 0 ]; do case "$1" in --label) label=$2; shift 2 ;; --filter) filter=$2; shift 2 ;; --first) first=$2; shift 2 ;; --yes) yes=1; shift ;; *) shift ;; esac; done
  cfg=$(s "$n" config); [ -n "$cfg" ] || { echo "평가가 없습니다: $n" >&2; exit 1; }; cfg="$ROOT/$cfg"
  read -r tests calls < <(count "$cfg" "$filter" "$first" "$(s "$n" callsPerTest)")
  echo "시험 ${tests}개, 예상 외부 호출 약 ${calls}회(추정 — 캐시에 있으면 덜 씀)"
  [ "$cmd" = count ] && exit 0
  pre=$(s "$n" preCheck); [ -n "$pre" ] && echo "사전 확인: $(bash -c "$pre")"
  max=$(s "$n" maxCalls)
  if [ -n "$max" ] && [ "$calls" -gt "$max" ] && [ -z "$yes" ]; then
    echo "예상 호출 ${calls}회가 maxCalls ${max}를 넘어 멈춥니다. --filter/--first로 줄이거나, 남은 한도를 확인한 뒤 --yes" >&2; exit 2; fi
  mkdir -p "$OUT/eval-$n-cases"; stamp=$(date '+%Y%m%d-%H%M%S'); raw="$OUT/eval-$n-cases/$stamp.json"
  args=(eval -c "$cfg" --no-share --no-write --no-table -o "$raw")
  [ -n "$filter" ] && args+=(--filter-pattern "$filter"); [ -n "$first" ] && args+=(--filter-first-n "$first")
  d=$(s "$n" delayMs); [ -n "$d" ] && args+=(--delay "$d"); j=$(s "$n" maxConcurrency); [ -n "$j" ] && args+=(-j "$j")
  ef=$(s "$n" envFile); [ -n "$ef" ] && args+=(--env-file "$ROOT/$ef")
  t0=$(date +%s)
  (cd "$(dirname "$cfg")" && npx -y "$PF" "${args[@]}") 2>&1 | grep -vE '^npm warn' | tail -6 || true
  [ -f "$raw" ] || { echo "promptfoo 결과 파일이 없습니다 — 위 출력 확인" >&2; exit 1; }
  EVAL_ROOT="$ROOT" python3 "$DIR/summarize.py" record "$raw" "$OUT" "$n" "$label" "$(git rev-parse --short HEAD 2>/dev/null || echo -)" "$(s "$n" env)" \
    "$(jq -c --arg n "$n" '.suites[$n].metrics // []' "$C")" "$(( $(date +%s) - t0 ))" "$filter${first:+ first=$first}" "$(s "$n" description)" > "$OUT/.eval-last.json"
  jq -r '"\(.name) [\(.label)] 통과 \(.passed)/\(.total) (\(.passRate)%) · " + ([.metrics|to_entries[]|"\(.key) \(.value)"]|join(" · ")) + " · \(.seconds)초"' "$OUT/.eval-last.json"
  log run "$n $label $(jq -c '{passRate,total,metrics}' "$OUT/.eval-last.json")"
  diffout=$(python3 "$DIR/summarize.py" diff "$OUT/eval-$n.jsonl" "" "" 2>/dev/null || true)
  [ -n "$diffout" ] && echo "$diffout"
  echo "리포트: $(jq --arg d "$diffout" '{plugin:"evalflow", kind:"eval", title:"평가 — \(.name) [\(.label)]",
    summary:("통과 \(.passed)/\(.total) (\(.passRate)%) · " + ([.metrics|to_entries[]|"\(.key) \(.value)"]|join(" · "))), env:.env,
    status:(if .newlyFailed > 0 then "fail" elif .passed < .total then "warn" else "ok" end),
    sections:[{heading:"요약", kv:[["설명",.description],["커밋",.commit],["통과","\(.passed)/\(.total)"],["걸린 시간","\(.seconds)초"],["범위",(if .scope=="" then "전체" else .scope end)],["케이스 원본",.raw]]},
      {heading:"지표(평균)", bars:{unit:"", items:[.metrics|to_entries[]|[.key,.value]]}},
      {heading:"틀린 케이스", table:{columns:["케이스","지표","이유"], rows:[.failed[]|[.id, ([.scores|to_entries[]|"\(.key) \(.value)"]|join(" · ")), .reason]]}},
      {heading:"이전 기록 대비", text:(if $d == "" then "비교할 이전 기록 없음" else $d end)}]}' "$OUT/.eval-last.json" | report)"
  nf=$(jq .newlyFailed "$OUT/.eval-last.json")
  [ "$nf" -gt 0 ] && notify "evalflow: 새로 틀린 케이스 ${nf}개" "$n — /evalflow:advise 로 원인·추천"
  rm -f "$OUT/.eval-last.json" ;;
diff)
  n=${2:?평가 이름}; f="$OUT/eval-$n.jsonl"; [ -f "$f" ] || { echo "기록이 없습니다: $f" >&2; exit 1; }
  python3 "$DIR/summarize.py" diff "$f" "${3:-}" "${4:-}" ;;
*) sed -n '2,10p' "$0"; exit 1 ;;
esac
