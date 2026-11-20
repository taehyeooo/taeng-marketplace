# 변경 기록

## 0.7.0 — 2026-11-20

- 디자인 설계·검토·한국어 문구 스킬 3개와 앱 내 시안 비교 HTML을 제거하고 `design` 하나로 통합했다. `/intaeng:디자인`은 새 스킬을 부른다.
- 사용자 흐름에서 시작하는 8단계, 사용자 선택 전 앱 코드 변경 금지, UX 체크리스트, 다른 기기 위임, 승인 후 무료 도구 설치, 설계·구현·사용자 테스트를 나눈 보고를 담았다.
- 14개 도구 참고 자료를 분리했다. 고정된 기기별 설치 표 대신 현재 기기의 실제 설치 상태를 확인한다.
- Claude 매니페스트·마켓플레이스와 Codex 공통 매니페스트 버전을 함께 올렸다. 두 도구 모두 같은 `skills/design/SKILL.md`를 사용한다.
- 새로 깔리는 템플릿과 다른 스킬의 호출을 갱신했다. 이미 설치한 프로젝트의 AGENTS.md·스킬 표는 프로젝트 소유이므로 해당 디자인 항목을 `design`으로 바꿔야 한다.

기준: 사용자 디자인 가이드(2026-11-20) 기준. 기기 정보와 특정 서비스·매니저 문구를 일반화했다.

갱신(병합 후): Claude Code에서 `/plugin marketplace update taeng-marketplace` 후 터미널에서 `claude plugin update intaeng@taeng-marketplace`, 새 세션. Codex에서 `codex plugin marketplace upgrade taeng-marketplace` 후 `/plugins`에서 intaeng 갱신 상태를 확인하고 새 세션을 시작한다.
