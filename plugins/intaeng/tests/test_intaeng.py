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
FORBIDDEN = re.compile(r"intaengligence|trova|투두|\btodo\b|solostack|librarian|gimtaeng|사용자 결정|\borca\b|C:\\Users|/c/Users", re.I)


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
        if os.name == "posix":  # 실행 권한이 없으면 git이 훅을 건너뛴다
            self.assertTrue(os.access(os.path.join(self.repo, ".githooks/commit-msg"), os.X_OK))

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


COMMANDS = (("지식베이스", "knowledge-base"), ("기획", "feature-spec"), ("디자인", "design-flow"),
            ("시작", "start-task"), ("마무리", "wrap-up"), ("이어하기", "resume"), ("머지", "merge-train"),
            ("맡기기", "delegate-pr"), ("스펙점검", "spec-check"))


class CommandTest(unittest.TestCase):
    def test_한글_명령은_commands에_있고_영어_스킬을_부른다(self):  # intaeng-plugin#R-1
        # 스킬 폴더·name이 한글이면 이름이 `-----`로 깨진다(2026-10-28 확인) — 한글은 명령 파일에만
        for command, skill in COMMANDS:
            with open(os.path.join(PLUGIN, "commands", command + ".md"), encoding="utf-8") as f:
                self.assertIn("intaeng:" + skill, f.read())
            self.assertTrue(os.path.isfile(os.path.join(PLUGIN, "skills", skill, "SKILL.md")), skill)
        for name in os.listdir(os.path.join(PLUGIN, "skills")):
            self.assertRegex(name, r"^[a-z0-9-]+$")


class FeatureSpecTest(unittest.TestCase):
    SKILL = os.path.join(PLUGIN, "skills", "feature-spec")

    def read(self, name):
        with open(os.path.join(self.SKILL, name), encoding="utf-8") as f:
            return f.read()

    def test_단계와_원칙이_다_있다(self):  # intaeng-plugin#R-10 intaeng-plugin#R-11 intaeng-plugin#R-17 intaeng-plugin#R-18
        text = self.read("SKILL.md")
        for heading in ("### 0. 아이디어 받기", "### 1. PRD 초안", "### 2. 기능 트리", "### 3. 기능별 상세",
                        "### 4. 데이터 모델", "### 5. 자체 점검", "### 6. 확정 → spec", "### 7. plan"):
            self.assertIn(heading, text)
        for rule in ("지식베이스 먼저", "객관식", "최대 4개", "(추천)", "추가 제안", "결정 사항",
                     "같이 하기", "맡기기", "가정 n", "완료 기준", "사람 손이 필요한 일", "확인 방법"):
            self.assertIn(rule, text)

    def test_채운_명세서와_plan이_깐_레포의_문서_검사를_통과한다(self):  # intaeng-plugin#R-12 intaeng-plugin#R-20
        with tempfile.TemporaryDirectory() as repo:
            run(["git", "init", "-q"], repo)
            with redirect_stdout(io.StringIO()):
                install.install(repo, hooks=False)
            spec = self.read("template.md").replace("<앱 이름>", "메모").replace(
                "- **R-1** 1.1 <세부 기능명> — <한 줄>", "- **R-1** 1.1 메모 쓰기 — 메모를 쓴다\n- **R-2** 1.2 메모 지우기 — 메모를 지운다")
            with open(os.path.join(repo, "docs/specs/2026-10-28-memo.md"), "w", encoding="utf-8") as f:
                f.write(spec)
            with open(os.path.join(repo, "docs/templates/plan.md"), encoding="utf-8") as f:
                self.assertIn("based_on", f.read())
            plan = ("---\ntitle: 메모 구현 순서\nversion: 1\nstatus: active\n"
                    "based_on: docs/specs/2026-10-28-memo.md v1\n---\n\n# 메모\n\n1. [ ] 쓰기 (R-1)\n2. [ ] 지우기 (R-2)\n")
            with open(os.path.join(repo, "docs/plans/2026-10-28-memo.md"), "w", encoding="utf-8") as f:
                f.write(plan)
            result = run([sys.executable, "scripts/check_docs.py"], repo)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            # 테스트를 아직 안 썼으니 "테스트가 인용하지 않은 요구사항" 경고는 맞다 — plan 인용 경고는 없어야 한다
            self.assertNotIn("plan", result.stdout)


class DesignFlowTest(unittest.TestCase):
    SKILLS = os.path.join(PLUGIN, "skills")

    def read(self, *parts):
        with open(os.path.join(self.SKILLS, *parts), encoding="utf-8") as f:
            return f.read()

    def test_네_단계와_원칙이_다_있다(self):  # intaeng-plugin#R-13 intaeng-plugin#R-14
        text = self.read("design-flow", "SKILL.md")
        for heading in ("## 1. 구조 시안 3개", "## 2. 세부 시안", "## 3. 적용", "## 4. 고도화"):
            self.assertIn(heading, text)
        for rule in ("큰 것 → 작은 것", "아티팩트로 그리지 않는다", "개발 서버에서만", "지식베이스 먼저",
                     "같이 하기", "맡기기", "3↔4", "스킬 적용 표", "대응한 스킬 규칙", "44×44px"):
            self.assertIn(rule, text)

    def test_함께_쓰는_스킬이_플러그인에_있다(self):  # intaeng-plugin#R-15
        text = self.read("design-flow", "SKILL.md")
        for skill in ("design-review", "ux-writing-ko"):
            self.assertIn("intaeng:" + skill, text)
            self.assertIn(f"name: {skill}\n", self.read(skill, "SKILL.md"))

    def test_나란히_보기는_외부_파일_없이_돈다(self):  # intaeng-plugin#R-13
        html = self.read("design-flow", "compare.html")
        self.assertIn("${CLAUDE_PLUGIN_ROOT}/skills/design-flow/compare.html", self.read("design-flow", "SKILL.md"))
        self.assertNotRegex(html, r"<(script|link)[^>]+(src|href)=\"https?://")
        for part in ("<iframe", "URLSearchParams", 'name="base"', 'name="v"'):
            self.assertIn(part, html.replace("createElement('iframe')", "<iframe"))


class FlowTest(unittest.TestCase):
    def read(self, skill):
        with open(os.path.join(PLUGIN, "skills", skill, "SKILL.md"), encoding="utf-8") as f:
            return f.read()

    def test_흐름_스킬이_규칙을_지킨다(self):  # intaeng-plugin#R-16
        for skill in ("start-task", "wrap-up", "resume", "merge-train", "delegate-pr", "spec-check"):
            self.assertIn(f"name: {skill}\n", self.read(skill))
        self.assertIn("intaeng:feature-spec", self.read("start-task"))  # 새 기능 기획은 /기획으로
        self.assertIn("--no-verify", self.read("merge-train"))  # 금지 문구
        self.assertIn("scripts/cleanup_worktree.py", self.read("merge-train"))
        for skill in ("wrap-up", "delegate-pr"):
            self.assertRegex(self.read(skill), r"서명|트레일러")

    def test_스킬끼리_부르는_이름이_다_있다(self):
        names = set(os.listdir(os.path.join(PLUGIN, "skills")))
        for skill in names:
            for ref in re.findall(r"intaeng:([a-z0-9-]+)", self.read(skill)):
                self.assertIn(ref, names, f"{skill}이 없는 스킬 intaeng:{ref}를 부른다")

    def test_스킬은_ADR을_번호가_아니라_주제로_가리킨다(self):
        # 레포마다 ADR 번호가 다르다 — 이미 지식베이스가 있는 레포에서 번호는 엉뚱한 결정을 가리킨다
        for skill in os.listdir(os.path.join(PLUGIN, "skills")):
            self.assertNotRegex(self.read(skill), r"ADR \d{4}", skill)


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
