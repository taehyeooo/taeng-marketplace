# promptfoo 결과(JSON) → 레포 기록(eval-<이름>.jsonl·.md)과 비교.
#   summarize.py record <promptfoo 결과> <결과 폴더> <이름> <이름표> <커밋> <환경> <지표 JSON 배열> <초> <범위> <설명>  → 요약 JSON(stdout)
#   summarize.py diff <eval-이름.jsonl> [이름표A 이름표B]                                                       → 새로 틀린/맞힌 케이스
# 기록 한 줄: {at, label, commit, env, scope, total, passed, passRate, metrics{이름: 평균}, cases{id: {pass, scores}}, raw, seconds}
# benchflow 지표로 쓰려면 cmd에 `tail -1 docs/eval/eval-<이름>.jsonl | jq .passRate`(또는 .metrics.<이름>)를 적는다.
import datetime, json, os, sys


def case_id(r):
    t = r.get("testCase") or {}
    return t.get("description") or json.dumps(r.get("vars", {}), ensure_ascii=False, sort_keys=True)[:80]


def load(path):
    return [json.loads(l) for l in open(path) if l.strip()] if os.path.exists(path) else []


def diff_rows(a, b):
    common = sorted(set(a["cases"]) & set(b["cases"]))
    newly_failed = [c for c in common if a["cases"][c]["pass"] and not b["cases"][c]["pass"]]
    newly_passed = [c for c in common if not a["cases"][c]["pass"] and b["cases"][c]["pass"]]
    return common, newly_failed, newly_passed


def record(raw, out, name, label, commit, env, metrics, seconds, scope, desc):
    res = json.load(open(raw))["results"]["results"]
    want = json.loads(metrics)
    cases, failed, sums = {}, [], {}
    for r in res:
        cid = case_id(r); scores = r.get("namedScores") or {}
        if want: scores = {k: v for k, v in scores.items() if k in want}
        cases[cid] = {"pass": bool(r.get("success")), "scores": {k: round(v, 4) for k, v in scores.items()}}
        for k, v in scores.items(): sums.setdefault(k, []).append(v)
        if not r.get("success"):
            g = r.get("gradingResult") or {}
            reasons = [c.get("reason", "") for c in g.get("componentResults", []) if not c.get("pass")] or [r.get("error") or g.get("reason", "")]
            out_txt = (r.get("response") or {}).get("output")
            failed.append({"id": cid, "scores": cases[cid]["scores"], "reason": " / ".join(x for x in reasons if x)[:300],
                           "output": (out_txt if isinstance(out_txt, str) else json.dumps(out_txt, ensure_ascii=False))[:500] if out_txt is not None else ""})
    total = len(cases); passed = sum(c["pass"] for c in cases.values())
    row = {"at": f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}", "label": label, "commit": commit, "env": env, "scope": scope,
           "total": total, "passed": passed, "passRate": round(passed / total * 100, 1) if total else 0,
           "metrics": {k: round(sum(v) / len(v), 4) for k, v in sums.items()}, "cases": cases,
           "raw": os.path.relpath(raw, os.environ.get("EVAL_ROOT", os.path.dirname(out))), "seconds": int(seconds)}
    path = os.path.join(out, f"eval-{name}.jsonl"); prev = load(path)
    newly = diff_rows(prev[-1], row)[1] if prev else []
    with open(path, "a") as f: f.write(json.dumps(row, ensure_ascii=False) + "\n")
    render(path, os.path.join(out, f"eval-{name}.md"), name, desc)
    print(json.dumps({"name": name, "description": desc} | {k: row[k] for k in ("label", "commit", "env", "scope", "total", "passed", "passRate", "metrics", "seconds", "raw")}
                     | {"failed": failed, "newlyFailed": len(newly)}, ensure_ascii=False))


def render(src, dst, name, desc):
    rows = load(src); keys = sorted({k for r in rows for k in r["metrics"]})
    lines = [f"# 평가 — {name}", "", desc, "", "promptfoo로 채점한 기록. 새 기록이 위. 지표는 케이스 평균(0~1).", "",
             "| 시각 | 이름표 | 커밋 | 환경 | 범위 | 통과 | 통과율 | " + " | ".join(keys) + " | 초 |",
             "|---|---|---|---|---|---|---|" + "---|" * len(keys) + "---|"]
    for r in reversed(rows):
        lines.append(f"| {r['at']} | {r['label']} | `{r['commit']}` | {r['env']} | {r['scope'] or '전체'} | {r['passed']}/{r['total']} | {r['passRate']}% | "
                     + " | ".join(str(r["metrics"].get(k, "-")) for k in keys) + f" | {r['seconds']} |")
    open(dst, "w").write("\n".join(lines) + "\n")


def diff(path, la, lb):
    rows = load(path)
    if len(rows) < 2: sys.exit(0)
    pick = lambda l: [r for r in rows if r["label"] == l][-1]
    a, b = (pick(la), pick(lb)) if la and lb else (rows[-2], rows[-1])
    common, nf, np_ = diff_rows(a, b)
    print(f"{a['label']}({a['commit']}) 통과 {a['passed']}/{a['total']} → {b['label']}({b['commit']}) {b['passed']}/{b['total']}, 같은 케이스 {len(common)}개 비교")
    for k in sorted(set(a["metrics"]) | set(b["metrics"])):
        print(f"  {k}: {a['metrics'].get(k, '-')} → {b['metrics'].get(k, '-')}")
    if a["env"] != b["env"]: print("주의: 두 기록의 환경이 다릅니다")
    if a["scope"] != b["scope"]: print(f"주의: 범위가 다릅니다({a['scope'] or '전체'} / {b['scope'] or '전체'}) — 겹치는 케이스만 비교")
    print("새로 틀림: " + (", ".join(nf) if nf else "없음"))
    print("새로 맞힘: " + (", ".join(np_) if np_ else "없음"))


if __name__ == "__main__":
    if sys.argv[1] == "record": record(*sys.argv[2:12])
    elif sys.argv[1] == "diff": diff(sys.argv[2], *(sys.argv[3:5] + ["", ""])[:2])
