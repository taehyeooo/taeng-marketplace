---
name: merge-train
description: 머지 대기 PR 여러 개를 순서대로 머지할 때 쓴다 — "PR 다 머지해줘", "#12 → #13 순서로 머지", "머지하고 정리해줘", 하나를 머지한 뒤 다음 PR이 main과 충돌할 때. 사용자 승인 확인 → PR마다 CI 통과 확인 → squash 머지 → 다음 PR을 main 위로 rebase(log.md·ADR 목록 충돌은 main 줄을 지키고 브랜치의 새 줄만 덧붙임) → 검사 재실행 → force-with-lease → CI → 머지, 끝나면 scripts/cleanup_worktree.py로 워크트리·브랜치 정리. 자율 모드(미리 받은 권한 묶음)면 묻지 않고 머지하고, 끝에 아침 보고(머지됨·승인 대기·막힘·기록 링크)를 쓴다.
---

# PR 이어서 머지하기

**머지는 사용자가 허락한 것만.** 시작 전에 "이 순서로 머지할까요: #A → #B → #C"를 보여 주고 답을 받는다. **자율 모드**면 허락은 시작할 때 받은 권한 묶음(spec `## 자율 모드 권한`, now.md 진행 중 줄의 링크)이다 — 묻지 않는 대신 PR마다 묶음 조건(CI·서명·`git diff --stat`에 "묻기" 경로 없음)을 확인하고, 하나라도 어긋나면 머지하지 않고 now.md `## 승인 대기`에 둔다(ADR 0016). CI가 실패한 PR은 머지하지 않는다(ADR 0008). 순서는 now.md에 적힌 것, 없으면 다른 PR이 기대는 것(공통 스크립트·ADR) 먼저.

## 1. PR 하나 머지
```bash
gh pr view <번호> --json title,mergeStateStatus,headRefName
gh pr checks <번호>                      # 모두 pass여야 한다. 진행 중이면 --watch
gh pr merge <번호> --squash              # 제목이 squash 커밋 제목이 된다 (타입: 내용)
git fetch origin
```
- `--delete-branch`는 쓰지 않는다 — 그 브랜치를 체크아웃한 워크트리가 있으면 로컬 삭제가 실패한다. 정리는 4번에서.
- `mergeStateStatus`가 `BEHIND`·`DIRTY`면 2번(rebase) 먼저.

## 2. 다음 PR을 main 위로 (그 PR의 워크트리에서)
```bash
git -C ../<레포 이름>-<slug> status --short     # 깨끗해야 한다
cd ../<레포 이름>-<slug>
git fetch origin && git rebase origin/main
```
충돌이 나면 파일마다:
- **`knowledge-base/log.md`** — main 쪽을 그대로 두고, 지금 재적용 중인 커밋이 **더한 줄만** 끝에 붙인다(손으로 합치다 기존 줄을 지우면 CI 실패, ADR 0010):
  ```bash
  L=knowledge-base/log.md
  git checkout --ours -- $L        # rebase 중 ours = main(옮겨 갈 쪽), theirs = 내 커밋
  git diff -U0 REBASE_HEAD~1 REBASE_HEAD -- $L | grep '^+' | grep -v '^+++' | cut -c2- >> $L
  git diff origin/main -- $L | grep '^-' | grep -v '^---' || echo "지운 줄 없음"   # 비어 있어야 한다
  git add $L
  ```
- **`knowledge-base/decisions/README.md`**(ADR 목록 표) — 같은 방법으로 `--ours`를 받은 뒤, 내 커밋이 더한 표 줄을 **표 마지막 줄 바로 아래**에 Edit로 넣는다(파일 끝이 아니라 — 표 뒤에 다른 내용이 있을 수 있다). 확인은 위와 같은 `git diff origin/main -- <파일>`에 `-` 줄 없음.
- **ADR 번호가 겹치면**(두 PR이 같은 번호) 나중 PR의 ADR을 다음 번호로 바꾼다 — 파일 이름, frontmatter `id`, 이 PR 안의 모든 링크(`grep -rn "00xx-" .`). 사용자에게 바꿨다고 알린다.
- **now.md** — main 쪽을 받고, 이 PR의 항목만 다시 반영한다(고쳐 쓰는 문서라 줄 단위로 합치지 않는다).
- 그 밖의 코드 충돌은 두 쪽 뜻을 읽고 합친다. 판단이 필요하면 멈추고 묻는다.
- `GIT_EDITOR=true git rebase --continue` — 커밋 메시지는 그대로 둔다(훅이 다시 검사한다). `--no-verify` 금지.

## 3. 다시 확인하고 올리기
```bash
python scripts/check_docs.py && python scripts/check_context.py
python scripts/check_log.py origin/main HEAD
# 고친 곳의 테스트 — 레포의 테스트·빌드 명령(CLAUDE.md나 README에 적힌 것)
git push --force-with-lease               # 이 PR의 브랜치에만. main·남의 브랜치에는 절대 안 한다
gh pr checks <번호> --watch
```
CI가 통과하면 1번으로 돌아가 이 PR을 머지하고, 다음 PR로.

## 4. 정리 (모두 머지한 뒤, 메인 체크아웃에서)
```bash
git pull --ff-only                                              # 메인 체크아웃의 main을 최신으로
python scripts/cleanup_worktree.py ../<레포 이름>-<slug>        # 또는 브랜치 이름. 원격 브랜치도 지우려면 --remote(사용자가 원할 때)
```
- 스크립트가 하는 것: PR이 MERGED인지(`gh`), 커밋 안 한 변경이 없는지 확인한 뒤 `git worktree remove` → 실패하면(Windows 긴 경로 — `node_modules` 등) **그 워크트리 폴더 하나만** `\\?\` 긴 경로 이름으로 지우고 `git worktree prune` → `git branch -D`(squash 머지라 `-d`는 거부). 메인 체크아웃·지금 서 있는 워크트리·등록되지 않은 경로는 지우지 않는다.
- 멈추면(변경 있음·PR이 머지 안 됨) 지우지 않은 이유가 나온다 — 변경을 버릴지, `--no-pr-check`(gh가 없을 때)로 할지는 사용자에게 묻는다.
- 이슈는 PR 본문 `Closes #n`으로 머지 때 닫힌다 — `gh issue view <n> --json state`로 확인. `Refs`만 있던 이슈는 남은 일이 없으면 사용자에게 닫을지 묻는다.
- 끝나면 now.md를 실제와 맞추고(남은 PR·다음 할 일) log.md에 한 항목 — 이것도 브랜치·PR로(`intaeng:wrap-up`).
- 자율 모드에서 "멈추고 묻는다"·"묻는다"(코드 충돌 판단, `--force`, 원격 브랜치 지우기)는 묻지 않고 하지 않는다 — now.md `## 승인 대기`에 한 줄 남기고 다음 PR로.

## 5. 아침 보고 (자율 모드가 끝나거나 멈출 때)
마지막으로 사용자에게 이 형식으로 보고한다. 같은 내용이 now.md("승인 대기"·"다음 할 일")와 실험 기록 "단계별 진행"·"결론"에 있어야 한다 — 보고만 있고 파일에 없으면 새 세션이 모른다.
```
아침 보고 — <작업> (#이슈), <시작 시각> ~ <끝 시각>
머지됨
- PR #n <제목> — CI 통과, <무엇이 됐나 한 줄>
승인 대기 (권한 밖이라 멈춘 것 — 답을 주면 이어서 한다)
- <무엇> — <왜 권한 밖> — <대신 한 것·PR #n 열림, CI 통과>
막힘 (멈춘 단계)
- <단계> — <원인> — <시도한 것> — <필요한 것>
리뷰로 확인할 가정
- spec 가정 n개 — <spec 경로>
기록
- 실험 기록 <경로> · now.md · log.md · 열린 PR <목록>
```
- 비어 있는 칸은 "없음"으로 남긴다(지우지 않는다). 사람 개입 횟수(시작 전 1회 + α)를 첫 줄에 붙여도 된다.
