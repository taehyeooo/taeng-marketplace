---
name: lidoff
description: 덮개를 닫으면 다시 잠들게 되돌리기 — 가방에 넣기 전에. macOS는 비밀번호 창이 뜸, Windows는 켜기 전 값으로 복원
---

# lidoff (lidflow)

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/lid.sh" off`를 Bash로 실행하고, 출력 첫 단어로 사용자에게 한 줄 보고한다.

`${CLAUDE_PLUGIN_ROOT}`는 이 플러그인 폴더다. 글자 그대로 남아 있으면(바꿔 주지 않는 도구, 예: Codex) 환경 변수 `PLUGIN_ROOT`·`CLAUDE_PLUGIN_ROOT`를, 그것도 없으면 이 SKILL.md에서 두 단계 위 폴더(`skills/<스킬>/`의 위의 위)를 쓴다.

- `ON`: 덮개를 닫아도 잠들지 않음. 가방에 넣기 전에 `/lidoff`(Codex에서는 lidoff 스킬)를 하라고 덧붙인다.
- `OFF`: 기본값, 덮개를 닫으면 잠듦.
- `UNSUPPORTED`: 이 운영체제는 지원하지 않는다고 출력 그대로 알린다.
- 실패(비밀번호 창 취소 등)하면 그대로 알리고 다시 시도하지 않는다.
