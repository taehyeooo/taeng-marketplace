---
name: lidon
description: 덮개를 닫아도 노트북이 잠들지 않게 켜기 — 휴대폰 원격(Orca·Paseo 등)으로 계속 쓸 때. macOS는 비밀번호 창이 뜸, Windows는 powercfg
---

# lidon (lidflow)

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/lid.sh" on`를 Bash로 실행하고, 출력 첫 단어로 사용자에게 한 줄 보고한다.

- `ON`: 덮개를 닫아도 잠들지 않음. 가방에 넣기 전에 `/lidoff`를 하라고 덧붙인다.
- `OFF`: 기본값, 덮개를 닫으면 잠듦.
- `UNSUPPORTED`: 이 운영체제는 지원하지 않는다고 출력 그대로 알린다.
- 실패(비밀번호 창 취소 등)하면 그대로 알리고 다시 시도하지 않는다.
- 전원 연결을 권한다(배터리로 덮개를 닫아 두면 열이 차고 빨리 닳음).
