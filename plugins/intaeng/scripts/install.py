#!/usr/bin/env python3
"""/지식베이스 — 일하는 방식의 뼈대를 레포에 깐다(templates/ → 대상 레포).

사용: python install.py <대상 레포> [--name 이름] [--intro 한 줄 소개] [--dry-run] [--no-hooks]

- 이미 있는 파일은 덮어쓰지 않고 옆에 `<이름>.intaeng.<확장자>`로 만든다 — 다르면 사람과 합친다.
- 템플릿 글의 {{name}}·{{intro}}를 바꾼다.
- --dry-run: 무엇이 생기는지만 보여 주고 아무것도 쓰지 않는다.
- 훅: 대상이 git 레포면 `git config core.hooksPath .githooks`(커밋 메시지 검사). --no-hooks면 하지 않는다.

외부 패키지 없이 표준 라이브러리만 쓴다.
"""

import argparse
import os
import subprocess
import sys

TEMPLATES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "templates")


def plan(target):
    """(템플릿 상대 경로, 쓸 경로, 상태: new|side) 목록. 쓸 경로가 있으면 옆 이름으로."""
    items = []
    for dirpath, dirs, files in os.walk(TEMPLATES):
        dirs[:] = [d for d in dirs if d != "__pycache__"]  # 템플릿 테스트를 돌리면 생긴다
        for file_name in sorted(files):
            rel = os.path.relpath(os.path.join(dirpath, file_name), TEMPLATES).replace(os.sep, "/")
            dest = os.path.join(target, rel)
            state = "new"
            if os.path.exists(dest):
                base, ext = os.path.splitext(dest)
                dest, state = f"{base}.intaeng{ext}", "side"
            items.append((rel, dest, state))
    return sorted(items)


def render(rel, values):
    with open(os.path.join(TEMPLATES, rel), encoding="utf-8") as f:
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
    args = parser.parse_args(argv[1:])
    install(args.target, args.name, args.intro, args.dry_run, not args.no_hooks)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
