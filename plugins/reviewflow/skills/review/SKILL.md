---
name: review
description: PR(또는 현재 브랜치)을 정확성·테스트·보안/시크릿·프로젝트 규칙(ADR·CLAUDE.md) 네 관점으로 동시에 리뷰하고, 지적을 코드로 다시 검증해 심각도 순으로 낸다. "리뷰해줘", "PR 봐줘", PR을 만들기 전·머지 전에 쓴다. --comment면 확인 후 PR 댓글 하나.
---

# PR 다관점 리뷰 (reviewflow)

인자: `[PR번호|브랜치] [--comment]` (없으면 현재 브랜치 vs 기본 브랜치)

## 순서
1. 재료 모으기: `run=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/review.sh" collect <PR번호|브랜치>)` → 실행 폴더. `meta.json`의 변경 파일 수·줄 수를 사용자에게 한 줄로 알린다. 변경분이 비면 멈춘다.
2. 관점별 리뷰어 4개를 **한 메시지에서 동시에** 부른다: `review-correctness`, `review-tests`, `review-security`, `review-rules`. 각자에게 실행 폴더 경로를 넘긴다. `rules.txt`가 비어 있으면 `review-rules`는 건너뛰고 "레포 규칙 문서 없음"으로 적는다.
3. 네 결과(JSON 배열)를 합치고, 같은 위치·같은 내용은 하나로 묶는다.
4. `review-verifier`에 합친 목록을 넘긴다. `REJECTED`는 빼고(개수만 `dropped`로 남김), `PLAUSIBLE`은 남기되 표시한다.
5. `<실행 폴더>/findings.json`에 `{"findings":[...], "dropped": N}`(심각도 높음→낮음 순)을 쓰고 `review.sh record <실행 폴더>`로 기록·리포트.
6. 사용자에게 결과: 지적마다 심각도 · 관점 · `경로:줄` · 한 문장 · 실패 시나리오. 높음이 없으면 그렇게 말한다. 지적이 0건이면 "확인한 관점과 범위"를 함께 말한다(0건 ≠ 문제없음).
7. `--comment`일 때만: `<실행 폴더>/comment.md`(위 결과를 PR 댓글 형식으로, 끝에 "reviewflow · 관점 4개 · 검증 후 N건")를 보여주고 **올릴지 사용자에게 묻는다**. 예일 때만 `review.sh comment <실행 폴더>`. 외부 게시라 승인 없이 올리지 않는다.
8. 사용자가 고치기로 한 지적은 고친 뒤 같은 PR로 다시 리뷰할 수 있다(이전 실행 폴더의 지적이 사라졌는지 비교).

## 지킬 것
- 리뷰어가 코드를 수정·커밋·push하지 않는다. 고치는 것은 사용자가 고른 뒤 따로.
- 시크릿 값은 결과·댓글에 옮겨 적지 않는다(위치만).
- 비용: Claude Code 안의 에이전트만 쓴다. 외부 유료 리뷰 서비스·API를 부르지 않는다.
