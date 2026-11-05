#!/usr/bin/env python3
"""/지식베이스 — 일하는 방식의 뼈대를 레포에 깐다(templates/ → 대상 레포).

사용: python install.py <대상 레포> [--name 이름] [--intro 한 줄 소개] [--dry-run] [--no-hooks]
      python install.py <대상 레포> --add rust [--dry-run]   (뼈대를 깐 레포에 언어별 규칙·검사·CI를 더한다)

- 이미 있는 파일은 덮어쓰지 않고 옆에 `<이름>.intaeng.<확장자>`로 만든다 — 다르면 사람과 합친다.
- 템플릿 글의 {{name}}·{{intro}}를 바꾼다.
- --dry-run: 무엇이 생기는지만 보여 주고 아무것도 쓰지 않는다.
- 훅: 대상이 git 레포면 `git config core.hooksPath .githooks`(커밋 메시지 검사). --no-hooks면 하지 않는다.
- --add <언어>: addons/<언어>/를 같은 방식(덮어쓰지 않음)으로 깔고, CLAUDE.md "경로별 규칙"에 규칙 파일 한 줄,
  .gitignore에 빌드 결과 한 줄을 더한다. 그 언어 프로젝트 파일(러스트면 Cargo.toml)이 먼저 있어야 한다 —
  규칙 파일 paths가 가리킬 파일이 없으면 컨텍스트 검사가 실패한다.

외부 패키지 없이 표준 라이브러리만 쓴다.
"""

import argparse
import os
import subprocess
import sys

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES = os.path.join(PLUGIN, "templates")
ADDONS = os.path.join(PLUGIN, "addons")
# 언어별 추가: 먼저 있어야 할 프로젝트 파일, CLAUDE.md "경로별 규칙"에 넣을 줄, .gitignore에 넣을 줄
ADDON_INFO = {
    "rust": {
        "needs": "Cargo.toml",
        "rule_line": "- [rust.md](.claude/rules/rust.md) — 러스트: 커밋 전 `sh scripts/check_rust.sh`(fmt·clippy·test), 테스트 먼저, `unwrap` 금지, 다른 서버와 쓰면 `127.0.0.1`만",
        "ignore": "target/",
    },
}
SKIP_DIRS = {".git", "node_modules", "target", "__pycache__"}


def plan(target, base=TEMPLATES):
    """(템플릿 상대 경로, 쓸 경로, 상태: new|side) 목록. 쓸 경로가 있으면 옆 이름으로."""
    items = []
    for dirpath, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d != "__pycache__"]  # 템플릿 테스트를 돌리면 생긴다
        for file_name in sorted(files):
            rel = os.path.relpath(os.path.join(dirpath, file_name), base).replace(os.sep, "/")
            dest = os.path.join(target, rel)
            state = "new"
            if os.path.exists(dest):
                stem, ext = os.path.splitext(dest)
                dest, state = f"{stem}.intaeng{ext}", "side"
            items.append((rel, dest, state))
    return sorted(items)


def render(rel, values, base=TEMPLATES):
    with open(os.path.join(base, rel), encoding="utf-8") as f:
        text = f.read()
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def install(target, name=None, intro="", dry_run=False, hooks=True):
    target = os.path.abspath(target)
    if not os.path.isdir(target):
        raise SystemExit(f"install: 폴더가 없다: {target}")
    values = {"name": name or os.path.basename(target), "intro": intro or "(한 줄 소개 — 누가, 무엇을 하면, 무엇을 얻나)"}
    items = plan(target)
    for rel, dest, state in items:
        mark = "새로" if state == "new" else "옆에(이미 있음)"
        print(f"{mark}: {os.path.relpath(dest, target).replace(os.sep, '/')}")
    if dry_run:
        print(f"(미리보기) 파일 {len(items)}개 — 아무것도 쓰지 않았다")
        return items
    for rel, dest, _ in items:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8", newline="\n") as f:
            f.write(render(rel, values))
        if rel.startswith(".githooks/") or rel.endswith(".sh"):
            # git은 실행 권한이 없는 훅을 조용히 건너뛴다(Linux·macOS) — Windows는 권한을 보지 않아 로컬에서 안 드러난다
            os.chmod(dest, 0o755)
    if hooks and os.path.isdir(os.path.join(target, ".git")):
        subprocess.run(["git", "-C", target, "config", "core.hooksPath", ".githooks"], check=True)
        print("훅 켬: core.hooksPath = .githooks")
    side = [d for _, d, s in items if s == "side"]
    print(f"깔았다: 파일 {len(items)}개" + (f", 옆에 만든 것 {len(side)}개 — 원래 파일과 합친다" if side else ""))
    return items


def has_file(target, name):
    for _, dirs, files in os.walk(target):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        if name in files:
            return True
    return False


def add_line_to_rules(text, line):
    """CLAUDE.md "## 경로별 규칙" 절의 마지막 목록 줄 뒤에 한 줄. 절이 없으면 None."""
    lines = text.split("\n")
    start = next((i for i, text_line in enumerate(lines) if text_line.startswith("## 경로별 규칙")), None)
    if start is None:
        return None
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    last = max((i for i in range(start, end) if lines[i].startswith("- ")), default=start)
    lines.insert(last + 1, line)
    return "\n".join(lines)


def add(target, addon, dry_run=False):
    """뼈대를 깐 레포에 언어별 규칙·검사·CI를 더한다(덮어쓰지 않음)."""
    target = os.path.abspath(target)
    if addon not in ADDON_INFO:
        raise SystemExit(f"install: 모르는 추가 `{addon}` — 있는 것: {', '.join(sorted(ADDON_INFO))}")
    info = ADDON_INFO[addon]
    if not has_file(target, info["needs"]):
        raise SystemExit(f"install: {info['needs']}가 없다 — 프로젝트를 먼저 만든 뒤(러스트면 `cargo init`) 다시 실행한다")
    base = os.path.join(ADDONS, addon)
    items = plan(target, base)
    claude = os.path.join(target, "CLAUDE.md")
    claude_text = open(claude, encoding="utf-8").read() if os.path.exists(claude) else None
    rule_name = info["rule_line"].split("](")[1].split(")")[0]
    need_rule_line = claude_text is not None and f"]({rule_name})" not in claude_text
    ignore = os.path.join(target, ".gitignore")
    ignore_lines = open(ignore, encoding="utf-8").read().splitlines() if os.path.exists(ignore) else []
    need_ignore = info["ignore"] not in ignore_lines
    for rel, dest, state in items:
        mark = "새로" if state == "new" else "옆에(이미 있음)"
        print(f"{mark}: {os.path.relpath(dest, target).replace(os.sep, '/')}")
    if need_rule_line:
        print("한 줄 더함: CLAUDE.md \"경로별 규칙\"")
    if need_ignore:
        print(f"한 줄 더함: .gitignore {info['ignore']}")
    if dry_run:
        print(f"(미리보기) 파일 {len(items)}개 — 아무것도 쓰지 않았다")
        return items
    for rel, dest, _ in items:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8", newline="\n") as f:
            f.write(render(rel, {}, base))
        if rel.endswith(".sh"):
            os.chmod(dest, 0o755)
    if need_rule_line:
        updated = add_line_to_rules(claude_text, info["rule_line"])
        if updated is None:
            print(f"CLAUDE.md에 \"## 경로별 규칙\"이 없다 — 이 줄을 손으로 넣는다: {info['rule_line']}")
        else:
            with open(claude, "w", encoding="utf-8", newline="\n") as f:
                f.write(updated)
    if need_ignore:
        with open(ignore, "a", encoding="utf-8", newline="\n") as f:
            if ignore_lines and ignore_lines[-1].strip():
                f.write("\n")
            f.write(f"# {addon} 빌드 결과\n{info['ignore']}\n")
    side = [d for _, d, s in items if s == "side"]
    print(f"더했다({addon}): 파일 {len(items)}개" + (f", 옆에 만든 것 {len(side)}개 — 원래 파일과 합친다" if side else ""))
    return items


def main(argv):
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="일하는 방식의 뼈대를 레포에 깐다")
    parser.add_argument("target")
    parser.add_argument("--name")
    parser.add_argument("--intro", default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-hooks", action="store_true")
    parser.add_argument("--add", metavar="언어", help="뼈대를 깐 레포에 언어별 규칙·검사·CI를 더한다: " + ", ".join(sorted(ADDON_INFO)))
    args = parser.parse_args(argv[1:])
    if args.add:
        add(args.target, args.add, args.dry_run)
        return 0
    install(args.target, args.name, args.intro, args.dry_run, not args.no_hooks)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
