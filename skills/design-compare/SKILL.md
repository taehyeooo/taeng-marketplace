---
name: design-compare
description: 화면을 고치기 전과 고친 뒤를 같은 기기에서 캡처해 나란히 붙인 비교 이미지를 만든다. 디자인 수정 PR, 회고·블로그 글, 사용자에게 변경을 보여줄 때 쓴다.
---

# 고치기 전·후 비교 (uiflow)

1. 고치기 전 화면을 띄운 상태에서: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/compare.sh" before <이름>`
2. 코드를 고치고(개발 서버면 바로 반영) 같은 화면으로 돌아와서: `compare.sh after <이름>`
3. 나온 비교 이미지를 PR 본문·기록에 넣는다. 같은 데이터·같은 글자 크기에서 찍어야 비교가 정직하다.
