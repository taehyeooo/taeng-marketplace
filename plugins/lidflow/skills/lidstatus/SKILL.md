---
name: lidstatus
description: 지금 덮개를 닫아도 안 잠드는 상태(lidon)인지 확인 — 비밀번호 필요 없음
---

# lidstatus (lidflow)

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/lid.sh" status`를 Bash로 실행하고, 출력 첫 단어로 사용자에게 한 줄 보고한다.

- `ON`: 덮개를 닫아도 잠들지 않음. 가방에 넣기 전에 `/lidoff`를 하라고 덧붙인다.
- `OFF`: 기본값, 덮개를 닫으면 잠듦.
- `UNSUPPORTED`: 이 운영체제는 지원하지 않는다고 출력 그대로 알린다.

