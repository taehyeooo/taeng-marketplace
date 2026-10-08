# startflow

새 서비스를 시작할 때 **내가 매번 처음에 세팅하던 값**을 한 번에 깔아 주는 Claude Code 플러그인입니다.
Trova를 만들며 직접 쓴 지침(CLAUDE.md)과 작업 중 정한 규칙들을 모아 템플릿으로 만들었습니다.

| 만드는 것 | 내용 |
|---|---|
| `CLAUDE.md` | 서비스 소개·기술 스택 + 고정 기본값: 비용 0원 원칙, 개발 순서(핵심 가정 검증 → API → 배포), API·코드 원칙, 하지 말 것, **작업 방식**(한국어, 범위 확정 → 방법 비교 → 검증 → 기록, 성능 근거, 실행 환경 표시, 시크릿, 시간 기록), Git 규칙, AI 도구(MCP) 사용 규칙, 자동화 플러그인 |
| `.gitignore` | 시크릿 블록(.env, 키, 로컬 설정) |
| `.env.example` | 키 이름만, "실제 값 금지" 머리말 |
| `.mcp.json` | Context7(최신 라이브러리 문서 조회, OAuth라 키 없음, 무료 월 1,000회). 이미 있으면 빠진 서버만 더함. 답변 `context7: false`면 생략 |
| `docs/experience-notes.md`, `docs/bench/` | 작업 기록·측정 기록 자리 |
| `docs/adr/README.md` | 결정 기록(ADR) 쓰는 법과 목록 — 문서 역할(ADR·작업 기록·CLAUDE.md) 나누기 |
| `.claude/settings.json` | 빌드·테스트·git add/commit 등 매번 허용하던 권한 |
| `~/.config/{devflow,qaflow,uiflow,benchflow}/<레포>.json` | 자동화 플러그인 설정 뼈대(레포 밖) |
| `~/.claude/CLAUDE.md` | 한국어 답변 규칙(없을 때만) |

이미 있는 파일은 덮어쓰지 않고 `*.startflow.*`로 옆에 만듭니다.

## 리포트
작업이 끝나면 HTML 리포트를 남깁니다: `~/.config/flow-reports/<플러그인>/<시각>-<종류>.html`.
다섯 flow 플러그인(startflow·devflow·qaflow·uiflow·benchflow)의 리포트가 한 목록 `~/.config/flow-reports/index.html`에 모입니다(최신이 위, 정상/확인 필요/실패 표시).

## 설치·사용
```
/plugin marketplace add taehyeooo/taeng-marketplace
/plugin install startflow@taeng-marketplace
```
새 레포에서 "처음 세팅해줘" → 서비스마다 다른 것(소개·스택·먼저 검증할 가정·화면 여부·빌드 명령)만 묻고 나머지는 기본값.
짝: [devflow](../devflow) · [qaflow](../qaflow) · [uiflow](../uiflow) · [benchflow](../benchflow)
