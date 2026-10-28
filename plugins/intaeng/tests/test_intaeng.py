#!/usr/bin/env python3
"""intaeng 플러그인 테스트 — 빈 레포에 깔고 검사가 통과하는지, 덮어쓰지 않는지, 개인 기록이 섞이지 않았는지.

실행: python plugins/intaeng/tests/test_intaeng.py
"""

import io
import os
import re
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(PLUGIN, "scripts"))
import install  # noqa: E402

# 공개 레포라 원본 레포의 개인 기록이 섞이면 안 된다(spec R-3) — 원본 레포·서비스 이름, 사용자 말 인용 표시, 내 PC 경로·메일
FORBIDDEN = re.compile(r"intaengligence|trova|투두|\btodo\b|solostack|librarian|gimtaeng|사용자 결정|C:\\Users|/c/Users", re.I)


def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8",
                          env={**os.environ, "PYTHONUTF8": "1"})


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = self.tmp.name
        run(["git", "init", "-q"], self.repo)

    def tearDown(self):
        self.tmp.cleanup()

    def install(self, **kw):
        with redirect_stdout(io.StringIO()):
            return install.install(self.repo, **kw)

    def read(self, rel):
        with open(os.path.join(self.repo, rel), encoding="utf-8") as f:
            return f.read()

    def test_깐_뒤_문서_컨텍스트_검사가_통과한다(self):  # intaeng-plugin#R-9
        self.install(name="trip-note", intro="여행 기록을 남긴다")
        for script in ("check_docs.py", "check_context.py"):
            result = run([sys.executable, f"scripts/{script}"], self.repo)
            self.assertEqual(result.returncode, 0, script + "\n" + result.stdout + result.stderr)

    def test_깐_스크립트의_테스트도_통과한다(self):  # intaeng-plugin#R-7
        self.install()
        for test in ("test_check_docs.py", "test_check_log.py", "test_check_context.py", "test_cleanup_worktree.py"):
            result = run([sys.executable, f"scripts/{test}"], self.repo)
            self.assertEqual(result.returncode, 0, test + "\n" + result.stderr[-2000:])
        result = run(["sh", "scripts/test-check-commit-msg.sh"], self.repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_구조와_이름_소개(self):  # intaeng-plugin#R-4 intaeng-plugin#R-5 intaeng-plugin#R-8
        self.install(name="trip-note", intro="여행 기록을 남긴다")
        claude = self.read("CLAUDE.md")
        self.assertTrue(claude.startswith("# trip-note\n\n여행 기록을 남긴다\n"))
        self.assertNotIn("{{", claude)
        for rel in ("knowledge-base/index.md", "knowledge-base/log.md", "knowledge-base/now.md",
                    "knowledge-base/decisions/README.md", "knowledge-base/troubleshooting/README.md",
                    "knowledge-base/concepts/README.md", "knowledge-base/runbooks/README.md",
                    "docs/specs/.gitkeep", "docs/plans/.gitkeep",
                    ".claude/rules/docs.md", ".claude/rules/skills.md",
                    ".githooks/commit-msg", ".github/workflows/rules.yml"):
            self.assertTrue(os.path.isfile(os.path.join(self.repo, rel)), rel)
        for name in ("spec", "plan", "adr", "interview", "troubleshooting", "rehearsal"):
            self.assertTrue(os.path.isfile(os.path.join(self.repo, "docs/templates", name + ".md")), name)

    def test_기본_원칙_ADR_16개가_목록에_있다(self):  # intaeng-plugin#R-6
        self.install()
        folder = os.path.join(self.repo, "knowledge-base/decisions")
        adrs = sorted(f for f in os.listdir(folder) if re.match(r"\d{4}-", f))
        self.assertEqual([a[:4] for a in adrs], [f"{n:04d}" for n in range(1, 17)])
        readme = self.read("knowledge-base/decisions/README.md")
        for adr in adrs:
            self.assertIn(adr, readme)

    def test_훅을_켠다(self):
        self.install()
        self.assertEqual(run(["git", "config", "core.hooksPath"], self.repo).stdout.strip(), ".githooks")

    def test_훅을_끄면_건드리지_않는다(self):
        self.install(hooks=False)
        self.assertEqual(run(["git", "config", "core.hooksPath"], self.repo).stdout.strip(), "")

    def test_커밋_메시지_훅이_서명을_막는다(self):
        self.install()
        run(["git", "config", "user.email", "t@example.com"], self.repo)
        run(["git", "config", "user.name", "t"], self.repo)
        run(["git", "add", "-A"], self.repo)
        bad = run(["git", "commit", "-q", "-m", "chore: 뼈대\n\nCo-Authored-By: someone <a@b.c>"], self.repo)
        self.assertNotEqual(bad.returncode, 0)
        ok = run(["git", "commit", "-q", "-m", "chore: 뼈대"], self.repo)
        self.assertEqual(ok.returncode, 0, ok.stderr)

    def test_미리보기는_아무것도_쓰지_않는다(self):  # intaeng-plugin#R-9
        items = self.install(dry_run=True)
        self.assertTrue(items)
        self.assertEqual(sorted(os.listdir(self.repo)), [".git"])

    def test_이미_있는_파일은_덮어쓰지_않고_옆에_만든다(self):
        with open(os.path.join(self.repo, "CLAUDE.md"), "w", encoding="utf-8") as f:
            f.write("내 규칙\n")
        self.install()
        self.assertEqual(self.read("CLAUDE.md"), "내 규칙\n")
        self.assertIn("## Git 컨벤션", self.read("CLAUDE.intaeng.md"))


class CommandTest(unittest.TestCase):
    def test_한글_명령은_commands에_있고_영어_스킬을_부른다(self):  # intaeng-plugin#R-1
        # 스킬 폴더·name이 한글이면 이름이 `-----`로 깨진다(2026-10-28 확인) — 한글은 명령 파일에만
        with open(os.path.join(PLUGIN, "commands", "지식베이스.md"), encoding="utf-8") as f:
            self.assertIn("intaeng:knowledge-base", f.read())
        for name in os.listdir(os.path.join(PLUGIN, "skills")):
            self.assertRegex(name, r"^[a-z0-9-]+$")


class LeakTest(unittest.TestCase):
    def test_플러그인에_원본_레포의_개인_기록이_없다(self):  # intaeng-plugin#R-3
        found = []
        for dirpath, dirs, files in os.walk(PLUGIN):
            dirs[:] = [d for d in dirs if d != "__pycache__"]
            for file_name in files:
                path = os.path.join(dirpath, file_name)
                if path == os.path.abspath(__file__):
                    continue
                with open(path, encoding="utf-8") as f:
                    for no, line in enumerate(f, 1):
                        if FORBIDDEN.search(line):
                            found.append(f"{os.path.relpath(path, PLUGIN)}:{no}: {line.strip()[:80]}")
        self.assertEqual(found, [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
