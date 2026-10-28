---
name: resume
description: 새 세션에서 하던 일을 이어받을 때 쓴다 — "하던 거 뭐였지", "이어서 하자", "어디까지 했지", "지금 상태 알려줘", 새 세션을 시작했는데 무엇을 할지 말하지 않았을 때. 인계 메모(knowledge-base/now.md)와 실제 상태(워크트리·열린 PR과 CI·열린 이슈·남은 브랜치)를 맞춰 보고 진행 중 / 다음 / 답이 필요한 것으로 요약하며, now.md가 실제와 어긋나면 알리고 고칠지 묻는다. 읽기만 한다. 자율 모드 작업이면 now.md의 권한 링크와 승인 대기 목록도 읽어 함께 보고한다.
---

# 하던 일 이어받기

인계 메모는 `knowledge-base/now.md`다(ADR 0015). 메모는 사람이 마지막에 고친 시점의 상태라서, **실제와 맞춰 본 뒤에** 요약한다. 이 스킬은 아무것도 바꾸지 않는다 — 고칠 것은 묻고, 답을 받은 뒤 고친다.

## 1. 모으기 (읽기만, 레포 안 아무 워크트리에서)
```bash
git fetch -q origin
git branch --show-current                 # 지금 워크트리의 브랜치
git worktree list                         # 워크트리마다 브랜치·커밋
git status --short                        # 커밋 안 한 변경
gh pr list --state open --json number,title,headRefName,isDraft,mergeStateStatus
gh pr checks <번호>                        # 열린 PR마다 CI(통과·실패·진행 중)
gh issue list --state open --json number,title
git log origin/main --oneline -5          # 최근 머지
```
- 그리고 `knowledge-base/now.md` 전체, `knowledge-base/log.md` 마지막 항목 하나.
- **자율 모드 작업**(now.md 진행 중 줄에 `자율 모드 — 권한: <spec 경로>`)이면 그 spec의 `## 자율 모드 권한`과 now.md `## 승인 대기`, 실험 기록의 "단계별 진행"을 읽는다(ADR 0016).
- **남은 브랜치는 PR 상태로 판단한다.** squash 머지라 `git branch -r --no-merged origin/main`은 머지된 브랜치도 "안 머지됨"으로 보인다. 브랜치마다 `gh pr list --state all --head <브랜치> --json number,state`로 MERGED / OPEN / CLOSED / PR 없음을 본다. PR 없는 원격 브랜치·워크트리만 "주인 없는 일"이다.
- 다른 워크트리에서 일하던 대화는 그 폴더에서 `claude --continue`(마지막 대화) 또는 `claude --resume`(목록에서 고르기)로 이어 간다. 대화 기록은 **폴더마다 따로** 저장된다 — 워크트리 폴더가 다르면 목록에 나오지 않으니, 어느 폴더에서 열지 알려 준다.

## 2. 맞춰 보기 (now.md vs 실제)
아래가 하나라도 맞으면 **now.md가 낡았다**:
- "진행 중"의 PR이 이미 MERGED/CLOSED이거나, 이슈가 닫혔다.
- 열린 PR·워크트리·이슈가 now.md 어디에도 없다.
- "마지막 갱신" 뒤에 main에 머지된 PR이 있는데 now.md가 그 결과를 모른다.

## 3. 보고 (이 형식으로, 짧게)
```
진행 중
- #12 로그인 화면 — feat/#12-login, 워크트리 ../<레포 이름>-login, PR #<번호> CI 통과, 머지 대기
다음
1. (now.md "다음 할 일" 순서대로, 실제와 맞춘 것)
답이 필요한 것
- (now.md "답이 필요한 것" + 실패한 CI·충돌 난 PR처럼 사람이 정해야 하는 것)
승인 대기 (자율 모드 — 권한 밖이라 멈춘 것)
- PR #<번호> <무엇> — <왜 권한 밖>, CI 통과, 머지 안 함
now.md와 다른 것
- "진행 중"의 PR #<번호>는 이미 머지됨(<커밋>) — 지우고 다음 할 일 1을 올릴까요?
정리할 것(선택)
- 머지된 PR의 원격 브랜치 <n>개가 남아 있음 — 지울까요?
```
- 끝에 "무엇부터 할까요?"로 묻는다. 다음 일이 새 작업이면 `intaeng:start-task`, PR을 올릴 때면 `intaeng:wrap-up`.
- **자율 모드가 진행 중이면 묻지 않는다** — 보고를 남기고 권한 묶음 안의 다음 단계로 이어 간다(승인 대기 항목은 건너뜀). 사용자가 승인 대기에 답했으면 그 답을 spec `## 자율 모드 권한`에 날짜와 함께 덧붙이고 이어 간다.

## 4. 사용자가 고치라고 하면
- now.md만 고친다(끝난 일 지우기, 순서 바꾸기, "마지막 갱신" 날짜). log.md는 이 스킬에서 쓰지 않는다 — 작업이 끝날 때 `intaeng:wrap-up`이 쓴다.
- now.md 수정도 브랜치·PR이 필요하다(메인 체크아웃에서 직접 고치지 않는다 — `CLAUDE.md` "워크트리 흐름"). 진행 중인 작업 브랜치가 있으면 그 PR에 넣고, 없으면 `intaeng:start-task`로 작은 `docs` 작업을 만든다.
- 원격 브랜치·워크트리 지우기는 사용자가 하나씩 허락한 것만, `intaeng:merge-train`의 정리 순서로.
