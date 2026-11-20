#!/usr/bin/env python3
"""intaeng 플러그인 테스트 — 빈 레포에 깔고 검사가 통과하는지, 덮어쓰지 않는지, 개인 기록이 섞이지 않았는지.

실행: python plugins/intaeng/tests/test_intaeng.py
"""

import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

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
                    ".githooks/commit-msg", ".github/workflows/rules.yml", "AGENTS.md"):
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


SAMPLE_MAIN = """fn main() {
    println!("{}", add(1, 2));
}

fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    #[test]
    fn adds() {
        assert_eq!(super::add(1, 2), 3);
    }
}
"""


class RustAddonTest(unittest.TestCase):
    """--add rust: 뼈대를 깐 레포에 러스트 규칙·검사·CI. cargo가 있으면(CI 러너) 샘플 프로젝트로 검사 스크립트까지."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = self.tmp.name
        run(["git", "init", "-q"], self.repo)
        with redirect_stdout(io.StringIO()):
            install.install(self.repo, hooks=False)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, text):
        path = os.path.join(self.repo, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

    def read(self, rel):
        with open(os.path.join(self.repo, rel), encoding="utf-8") as f:
            return f.read()

    def sample(self):
        self.write("worker/Cargo.toml", '[package]\nname = "worker"\nversion = "0.1.0"\nedition = "2021"\n')
        self.write("worker/src/main.rs", SAMPLE_MAIN)

    def add(self, **kw):
        with redirect_stdout(io.StringIO()):
            return install.add(self.repo, "rust", **kw)

    def test_Cargo_toml이_없으면_멈춘다(self):  # intaeng-plugin#R-21
        with self.assertRaises(SystemExit):
            self.add()
        self.assertFalse(os.path.exists(os.path.join(self.repo, ".claude/rules/rust.md")))

    def test_더한_뒤_컨텍스트_검사가_통과한다(self):  # intaeng-plugin#R-21
        self.sample()
        self.add()
        for rel in (".claude/rules/rust.md", "scripts/check_rust.sh", ".github/workflows/rust.yml"):
            self.assertTrue(os.path.isfile(os.path.join(self.repo, rel)), rel)
        rules = self.read("CLAUDE.md").split("## 경로별 규칙")[1].split("\n## ")[0]
        self.assertIn("](.claude/rules/rust.md)", rules)  # 다른 절이 아니라 경로별 규칙 목록에
        self.assertIn("target/", self.read(".gitignore").splitlines())
        result = run([sys.executable, "scripts/check_context.py"], self.repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_두_번_해도_줄이_겹치지_않고_덮어쓰지_않는다(self):
        self.sample()
        self.add()
        self.add()
        self.assertEqual(self.read("CLAUDE.md").count("](.claude/rules/rust.md)"), 1)
        self.assertEqual(self.read(".gitignore").splitlines().count("target/"), 1)
        self.assertTrue(os.path.isfile(os.path.join(self.repo, ".claude/rules/rust.intaeng.md")))

    def test_미리보기는_아무것도_쓰지_않는다(self):
        self.sample()
        before = self.read("CLAUDE.md")
        self.add(dry_run=True)
        self.assertEqual(self.read("CLAUDE.md"), before)
        self.assertFalse(os.path.exists(os.path.join(self.repo, ".claude/rules/rust.md")))
        self.assertFalse(os.path.exists(os.path.join(self.repo, ".gitignore")))

    def test_러스트_프로젝트가_없으면_검사_스크립트는_건너뛴다(self):
        self.sample()
        self.add()
        os.remove(os.path.join(self.repo, "worker/Cargo.toml"))
        result = run(["sh", "scripts/check_rust.sh"], self.repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("건너뜀", result.stdout)

    @unittest.skipUnless(shutil.which("cargo"), "cargo 없음 — CI 러너에서 돈다")
    def test_검사_스크립트가_통과하고_망가뜨리면_잡는다(self):  # intaeng-plugin#R-21
        self.sample()
        self.add()
        run(["git", "add", "-A"], self.repo)  # 스크립트는 git이 아는 Cargo.toml만 본다
        ok = run(["sh", "scripts/check_rust.sh"], self.repo)
        self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
        self.assertIn("러스트 검사 통과", ok.stdout)
        broken = {
            "포맷": SAMPLE_MAIN.replace("    a + b", "a+b"),
            "clippy 경고(쓰지 않는 변수)": SAMPLE_MAIN.replace("    a + b", "    let unused = 1;\n    a + b"),
            "테스트": SAMPLE_MAIN.replace("super::add(1, 2), 3", "super::add(1, 2), 4"),
        }
        for what, text in broken.items():
            self.write("worker/src/main.rs", text)
            bad = run(["sh", "scripts/check_rust.sh"], self.repo)
            self.assertNotEqual(bad.returncode, 0, what)


COMMANDS = (("지식베이스", "knowledge-base"), ("기획", "feature-spec"), ("디자인", "design"),
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


class DesignTest(unittest.TestCase):
    def read(self, rel="skills/design/SKILL.md"):
        return (Path(PLUGIN) / rel).read_text(encoding="utf-8")

    def test_8단계_이름과_순서(self):  # intaeng-plugin#R-13
        steps = re.findall(r"^\| ([1-8]\. [^|]+) \|", self.read(), re.M)
        self.assertEqual(steps, ["1. 사용자 흐름 확인", "2. 도구 고르기", "3. 시안 3개",
                                 "4. 사용자 선택", "5. 세부", "6. 적용", "7. 검수", "8. 보고"])

    def test_선택_전_코드_변경과_설치_승인_경계(self):  # intaeng-plugin#R-14 intaeng-plugin#R-15
        text = self.read()
        for rule in ("사용자 선택 전에는 실제 앱 코드를 바꾸지 않고", "승인 전에는 설치하지 않는다",
                     "무료인지", "설치 스크립트·실행 명령", "유료면 설치하지 않고 다시 묻는다"):
            self.assertIn(rule, text)

    def test_보고는_설계_구현_사용자_테스트를_구분(self):  # intaeng-plugin#R-15
        report = self.read().split("## 보고 형식", 1)[1].split("## 사용 결과 기록 예시", 1)[0]
        labels = re.findall(r"^\| ([^|]+) \|", report, re.M)
        self.assertEqual(labels, ["구분", "설계 제안", "구현 확인", "실제 사용자 테스트 결과"])
        self.assertIn("하지 않았다면 검증 필요", report)
        self.assertIn("실제 사용자 테스트로 보고하지 않는다", report)

    def test_자율_모드도_사용자_시안_선택을_기다린다(self):  # intaeng-plugin#R-14
        start = self.read("skills/start-task/SKILL.md").split("## 6. 자율 모드", 1)[1]
        self.assertIn("시안 선택은 가정으로 대신하지 않는다", start)
        self.assertIn("사용자 선택이 없으면 승인 대기에", start)
        for path in ("skills/design/SKILL.md", "skills/delegate-pr/SKILL.md",
                     "templates/knowledge-base/decisions/0016-autonomous-mode-permission-bundle.md"):
            self.assertIn("자율 모드에서도 시안 선택은 사용자 몫이며, 워커는 가정으로 고르지 않는다", self.read(path))

    def test_검수_구체_규칙과_사용_기록을_유지한다(self):  # intaeng-plugin#R-15
        text = self.read()
        checklist = text.split("## 7단계 검수 체크리스트", 1)[1].split("## 다른 레포", 1)[0]
        for rule in ("해요체", "4.5:1", "3:1", "7:1", "44×44px", "8px", "word-break: keep-all",
                     "overflow-wrap: anywhere", "Intl.NumberFormat('ko-KR')",
                     "Intl.DateTimeFormat('ko-KR', { timeZone: 'Asia/Seoul' })"):
            self.assertIn(rule, checklist)
        self.assertIn("사용자 흐름·화면별 상태·예외 상황·사용자 테스트 결과", text)
        sample = text.split("## 사용 결과 기록 예시", 1)[1]
        for field in ("작업:", "사용자 목표:", "UX 흐름:", "선택:", "이유:", "UI 범위:",
                      "UX 범위:", "구현 검증:", "사용성 검증:", "기록:", "미확인:"):
            self.assertIn(field, sample)

    def test_레포_전체에_옛_디자인_이름이_없다(self):  # intaeng-plugin#R-13
        root = Path(PLUGIN).parents[1]
        names = ["design" + "-flow", "design" + "-review", "ux-writing" + "-ko"]
        paths = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                                        cwd=root).decode("utf-8").split("\0")
        for rel in filter(None, paths):
            path = root / rel
            if not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeError:
                continue  # binary assets
            for name in names:
                self.assertNotIn(name, rel, rel)
                self.assertNotIn(name, text, rel)

    def test_디자인_스킬과_참고_링크가_설치_패키지에_있다(self):  # intaeng-plugin#R-13
        from pathlib import Path
        folder = Path(PLUGIN) / "skills" / "design"
        text = (folder / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("name: design\n", text)
        links = re.findall(r"\]\((references/[^)]+)\)", text)
        self.assertEqual(len(set(links)), 14)
        self.assertEqual(set(links), {f"references/{f.name}" for f in (folder / "references").glob("*.md")})
        for link in links:
            body = (folder / link).read_text(encoding="utf-8")
            self.assertIn("핵심 기능", body, link)
            self.assertIn("UX 활용 상황", body, link)
            self.assertRegex(body, r"https://", link)

    def test_명령과_템플릿이_존재하는_스킬만_부른다(self):
        from pathlib import Path
        base = Path(PLUGIN)
        names = {p.name for p in (base / "skills").iterdir() if p.is_dir()}
        self.assertEqual(names, {skill for _, skill in COMMANDS})
        for directory in ("commands", "templates"):
            for path in (base / directory).rglob("*.md"):
                for ref in re.findall(r"intaeng:([a-z0-9-]+)", path.read_text(encoding="utf-8")):
                    self.assertIn(ref, names, str(path))


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


class CodexTest(unittest.TestCase):
    """Codex 등 다른 에이전트 — 공통 매니페스트(Agent Plugins)·.agents 마켓플레이스·도구 중립 스킬·깐 레포의 AGENTS.md."""
    MARKET = os.path.dirname(os.path.dirname(PLUGIN))

    def load(self, *parts):
        with open(os.path.join(*parts), encoding="utf-8") as f:
            return json.load(f)

    def test_두_매니페스트의_이름과_버전이_같다(self):  # intaeng-plugin#R-22
        portable = self.load(PLUGIN, "plugin.json")
        claude = self.load(PLUGIN, ".claude-plugin", "plugin.json")
        listed = [p for p in self.load(self.MARKET, ".claude-plugin", "marketplace.json")["plugins"] if p["name"] == "intaeng"][0]
        self.assertEqual(portable["$schema"], "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json")
        self.assertEqual((portable["name"], portable["version"]), (claude["name"], claude["version"]))
        self.assertEqual(listed["version"], claude["version"])

    def test_codex_마켓플레이스가_플러그인_폴더를_가리킨다(self):  # intaeng-plugin#R-22
        market = self.load(self.MARKET, ".agents", "plugins", "marketplace.json")
        entry = [p for p in market["plugins"] if p["name"] == "intaeng"][0]
        self.assertEqual(entry["source"]["source"], "local")
        self.assertTrue(os.path.isfile(os.path.join(self.MARKET, entry["source"]["path"], "plugin.json")))
        self.assertEqual(entry["policy"]["installation"], "AVAILABLE")

    def test_스킬_글이_Claude만_전제하지_않는다(self):  # intaeng-plugin#R-22
        # 명령(`/intaeng:기획`)은 Claude Code에만 있다 — 본문에서 부를 때는 스킬 이름을 같이
        for skill in os.listdir(os.path.join(PLUGIN, "skills")):
            with open(os.path.join(PLUGIN, "skills", skill, "SKILL.md"), encoding="utf-8") as f:
                body = f.read().split("\n---\n", 1)[1]
            self.assertNotRegex(body, r"Claude가|Claude는|다른 Claude", skill)
            self.assertNotRegex(body, r"`/intaeng:(기획|디자인)`(?!\()", skill)
            if "${CLAUDE_PLUGIN_ROOT}" in body:
                self.assertRegex(body, r"PLUGIN_ROOT`|SKILL\.md가 있는 폴더", skill)  # 바꿔 주지 않는 도구용 대안

    def test_깐_레포의_AGENTS_md가_CLAUDE_md와_명령표를_가리킨다(self):  # intaeng-plugin#R-22
        with tempfile.TemporaryDirectory() as repo:
            run(["git", "init", "-q"], repo)
            with redirect_stdout(io.StringIO()):
                install.install(repo, name="trip-note", hooks=False)
            with open(os.path.join(repo, "AGENTS.md"), encoding="utf-8") as f:
                agents = f.read()
        self.assertTrue(agents.startswith("# trip-note"))
        self.assertIn("](CLAUDE.md)", agents)
        for command, skill in COMMANDS:
            self.assertIn(f"| `/intaeng:{command}` | `{skill}` |", agents)


# Source provenance is not part of the portable design package.
DESIGN_SOURCE_PRIVATE = re.compile(
    r"taeng-agent-manager|docs/design-guide|원본 blob|a17422fb980ed1a45161036e4075fd7a574e8a0d"
    r"|(?:기준|원본|출처):[^\n]*(?:PR\s*#\d+|\b[0-9a-f]{40}\b)", re.I)


class LeakTest(unittest.TestCase):
    def test_디자인_원본_레포_식별자가_공개_파일에_없다(self):  # intaeng-plugin#R-3
        root = Path(PLUGIN).parents[1]
        paths = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                                        cwd=root).decode("utf-8").split("\0")
        for rel in filter(None, paths):
            path = root / rel
            if not path.is_file() or path.resolve() == Path(__file__).resolve():
                continue  # detector definitions intentionally name the forbidden source
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeError:
                continue
            self.assertNotRegex(text, DESIGN_SOURCE_PRIVATE, rel)

    def test_원본_식별자_검사는_레포_브랜치_출처_해시를_잡는다(self):
        for text in ("taehyeooo/taeng-agent-manager", "docs/design-guide", "원본 blob: deadbeef",
                     "a17422fb980ed1a45161036e4075fd7a574e8a0d", "기준: 다른 문서(PR #15)",
                     "출처: " + "f" * 40):
            self.assertRegex(text, DESIGN_SOURCE_PRIVATE)


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
