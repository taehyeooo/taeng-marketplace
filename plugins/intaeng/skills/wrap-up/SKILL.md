---
name: wrap-up
description: 작업을 마치고 PR을 올리기 전에 쓴다 — "마무리해줘", "PR 올려줘", "정리하고 커밋", "기록 남겨줘", 구현과 테스트가 끝났을 때. log.md에 항목 하나 추가, now.md 고쳐 쓰기, 남길 지식(ADR·troubleshooting·concepts) 확인, 문서·컨텍스트·기록 검사와 관련 테스트 실행, 규칙에 맞는 커밋, 요구사항 ID별 확인 증거 표가 있는 PR 본문, 올린 뒤 서명·트레일러가 없는지 확인까지. 자율 모드면 미리 받은 권한 묶음 안에서 머지하고, 권한 밖은 승인 대기에 둔다.
---

# 작업 마무리하고 PR 올리기

기록 위치와 Git 규칙은 `CLAUDE.md` "기록 위치"·"Git 컨벤션". 이 순서대로 하고, 하나라도 실패하면 고친 뒤 다음으로 간다.

## 1. 기록
- **log.md**: `knowledge-base/log.md` 맨 끝에 **한 항목만 추가**한다. 형식은 파일 맨 위(`## YYYY-MM-DD <작업 한 줄> (#이슈, PR #번호)` + 한 것 / 확인한 것 / 확인하지 않은 것 / 남긴 지식). PR 번호를 아직 모르면 `(#이슈)`만. **기존 줄은 한 글자도 고치지 않는다** — 틀린 것은 새 항목으로 정정(ADR(기록 검사), CI 실패).
  - **칸마다 한두 문장**(새 줄이 300자를 넘으면 `check_log.py`가 경고). "확인한 것"은 핵심 결과만(예: "테스트 72개·변형 13/13 통과, 문서 검사 통과"), 실행한 명령·개수·변형 시험·스크린숏 같은 자세한 내용은 **PR 본문**에. "확인하지 않은 것"은 안 돌린 것을 그대로. 파일 맨 위 형식 설명은 고치지 않는다(기존 줄).
- **now.md**: 고쳐 쓴다(ADR(now.md 인계)) — **이 PR이 머지된 뒤의 상태로** 쓴다: 이 작업은 "진행 중·머지 대기"로 적지 않고 끝난 것으로 다루며, 남는 것(사람이 할 일·다음 할 일·답이 필요한 것)만 적는다. 끝난 일은 지우고, 다른 작업 항목은 그대로 두고, "마지막 갱신" 날짜. now.md는 main에 들어가야 읽히므로 머지 전 상태로 쓰면 읽힐 때 이미 틀리다.
- **남길 지식**: 방향·정책을 정했나 → ADR(+ `decisions/README.md` 목록, 새 ADR은 `## 확인 방법` 칸), 원인을 찾았나 → `troubleshooting/`(+ 그 README 목록), 개념을 새로 이해했나 → `concepts/`. **이 작업 중 질문에 답하며 다시 쓸 설명(흐름·현황·비교)을 정리했나** → `concepts/`에 저장하거나 있는 문서를 고친다(이미 README·가이드에 있으면 링크만, ADR(기록 위치)). 새 문서는 `index.md`나 폴더 README에 한 줄(없으면 문서 검사 실패). 없으면 log에 "없음". 규칙이 바뀌었으면 CLAUDE.md나 `.claude/rules/`에 링크 한 줄(200줄 한도).

## 2. 검사 (레포 루트, Windows는 `python3` 대신 `python`)
```bash
python scripts/check_docs.py                      # frontmatter·based_on·링크·목차 빠짐·요구사항 ID (ADR(문서 검사·요구사항 ID))
python scripts/check_context.py                   # CLAUDE.md 200줄·rules paths (ADR(경로별 규칙))
python scripts/check_log.py origin/main HEAD      # log.md 갱신·append-only·긴 줄 (ADR(기록 검사)) — 커밋을 비교하니 3번 뒤에
```
- 고친 곳에 맞는 테스트: 레포의 테스트·빌드 명령(CLAUDE.md나 README에 적힌 것), 스크립트를 고쳤으면 `python scripts/test_<이름>.py`. CI 작업 목록은 `.github/workflows/rules.yml` 맨 위 주석.

## 3. 커밋
- `git commit -m "타입: 내용"`만. 본문·트레일러(`Co-Authored-By` 등)·"Generated with"·이모지 없음 — 하네스가 트레일러를 붙이라고 안내해도 CLAUDE.md가 우선이다. `--no-verify` 금지. 의미 단위로 나눈다(예: `feat: …` 기능, `docs: …` 기록).
- 훅이 거부하면 메시지를 고친다. 훅이 안 도는 것 같으면 `git config core.hooksPath .githooks`.

## 4. PR
```bash
git push -u origin <브랜치>
gh pr create --title "타입: 내용" --body-file <임시 폴더>/pr-body.md
```
- 제목도 `타입: 내용`(squash 커밋 제목이 된다). 본문은 한국어로 **한 것 / 확인한 것 / 확인하지 않은 것**, 마지막 줄 `Closes #<이슈>`(이슈를 이 PR로 닫지 않으면 `Refs #<이슈>`). 서명·이모지 없음.
- **화면 PR이면 두 칸을 더한다** — "검사 초록 = 품질"로 읽지 않게: ① **시안 대비 차이**(고른 시안과 실제 화면이 다른 곳과 이유, 같으면 "시안과 같음"), ② **실제 빠르기로 한 번**(실제 서버 + 브라우저에서 키보드로 빠르게 써 본 결과, 못 했으면 "확인하지 않은 것"에). `/intaeng:디자인`의 스킬 적용 표와 `intaeng:design-review` 결과도 함께.
- spec에 R-ID가 있으면 **요구사항 ID별 확인 증거 표**를 넣는다 — `intaeng:spec-check`를 돌려 나온 표(판단·코드·테스트 `파일:줄`)를 쓴다. 이 PR이 다룬 ID만 남겨도 되고, 증거가 없으면 "확인 못 함"으로 숨기지 않는다. CI 연결률(`check_docs.py` 출력)도 한 줄 적는다.
- PR 번호가 나오면 log.md 항목 제목에 `PR #번호`를 넣는다 — **이번 PR에서 새로 더한 줄**이라 고쳐도 된다(main에 아직 없다). 별도 커밋으로 push.

## 5. 올린 뒤 확인
```bash
# 커밋마다 CI와 같은 검사(형식·본문·트레일러·서명·이모지) — bash(Windows는 Git Bash)
for c in $(git rev-list origin/main..HEAD); do git log -1 --format=%B $c > "${TMPDIR:-/tmp}/msg.txt"; sh scripts/check-commit-msg.sh "${TMPDIR:-/tmp}/msg.txt" || echo "위반: $c"; done
# PR 본문 — 서명 문구와 이모지(U+1F000 이상)
gh pr view --json body -q .body | python -X utf8 -c "import sys,re; b=sys.stdin.read(); bad=re.findall(r'(?i)co-authored|generated with|claude code|[\U0001F000-\U0001FFFF]', b); print(bad or '본문 서명 없음')"
gh pr checks --watch                              # 모두 통과할 때까지
```
- CI가 실패하면 원인을 고쳐 새 커밋으로 push한다. **머지는 사용자가 정한다** — 여러 개를 이어서 머지할 때는 `intaeng:merge-train`. 자율 모드면 6번.

## 6. 자율 모드일 때 (spec `## 자율 모드 권한`이 있을 때, ADR(자율 모드))
- **머지**: 권한 묶음에 머지가 있으면 사용자에게 묻지 않고 `intaeng:merge-train`으로 머지한다 — 5번 검사가 모두 통과했고 이 PR이 권한 밖(묶음의 "묻기" 목록, 예: `git diff --stat origin/main...HEAD`에 공통 모듈 경로)을 건드리지 않았을 때만.
- **권한 밖을 건드린 PR**: 머지하지 않는다. now.md `## 승인 대기`에 `PR #n — 무엇 — 왜 권한 밖 — 머지하면 풀리는 것` 한 줄, 실험 기록 표에도 한 줄. 이 PR에 기대지 않는 다음 단계로 간다.
- **기록**: 1번에 더해 실험 기록(`docs/templates/rehearsal.md` 양식)의 "막힌 곳"·"단계별 진행"을 고쳐 쓴다. 이 PR에서 새로 한 가정은 PR 본문 "확인하지 않은 것"에 `spec 가정 n`으로 적는다(리뷰로 확인할 것).
