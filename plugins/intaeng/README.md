# intaeng

**내가 없어도 개발이 돌아가는 레포**를 만드는 Claude Code 플러그인입니다. 판단 기준과 기록을 문서로 꺼내, AI와 사람이 같은 기준으로 일하게 합니다.

## 설치
```
/plugin marketplace add taehyeooo/taeng-marketplace
/plugin install intaeng@taeng-marketplace
```

## 명령

| 명령 | 하는 일 | 상태 |
|---|---|---|
| `/intaeng:지식베이스` | 이 레포에 일하는 방식의 뼈대를 깐다 | 있음 |
| `/intaeng:기획` | 아이디어 → PRD → 기능 트리 → 기능별 상세 → 데이터 모델 → 자체 점검 → 기능명세서(spec)·구현 순서(plan). 애매한 정책은 객관식으로 묻고, 이미 정한 건 지식베이스에서 찾는다 | 있음 |
| `/intaeng:디자인` | 사용자 흐름 → 도구 선택 → 시안 3개 → 사용자 선택 → 세부 → 적용 → 검수 → 보고 | 있음 |
| `/intaeng:시작` | 새 작업 — 이슈 → 브랜치 → 워크트리, 맥락 읽기, 새 기능이면 /기획·화면이면 /디자인으로. 맡기고 자리를 비우면 자율 모드 | 있음 |
| `/intaeng:마무리` | PR 전 — log·now 기록, 검사·테스트, 규칙에 맞는 커밋, 요구사항별 확인 증거 PR, 서명 확인 | 있음 |
| `/intaeng:이어하기` | 새 세션 — now.md와 실제 상태(워크트리·PR·CI·이슈)를 맞춰 보고 요약(읽기만) | 있음 |
| `/intaeng:머지` | 머지 대기 PR을 순서대로 — 허락받고 CI 통과한 것만, 충돌 처리, 워크트리 정리 | 있음 |
| `/intaeng:맡기기` | PR 하나 크기의 일을 하위 에이전트에게 — 지시문, 받은 뒤 CI·서명 확인 | 있음 |
| `/intaeng:스펙점검` | 요구사항(R-ID)이 코드에 구현됐는지 표와 일치율로(보고만) | 있음 |

- 플러그인 명령은 앞에 `intaeng:`이 붙어 보입니다. `/지식베이스`까지 치면 목록에서 고를 수 있습니다.
- 한글 이름은 명령(`commands/`)에만 씁니다. 스킬 폴더 이름을 한글로 하면 이름이 `-----`로 깨집니다(2026-10-28 확인). 그래서 스킬은 영어 이름(`intaeng:knowledge-base`)이고, 한글 명령이 그 스킬을 부릅니다. 스킬은 "지식베이스 깔아줘" 같은 말로도 불립니다.

## /기획 — 기능명세서

목표는 **코딩 전에 애매한 결정을 전부 끝내 두는 것**입니다. "내가 없어도 개발"은 개발 도중 사람을 찾지 않는다는 뜻이라, 결정은 시작할 때 한 번 합니다.

| 단계 | 하는 일 |
|---|---|
| 0 아이디어 | 앱·핵심 기능·사용자·플랫폼·스택, 완료 기준을 무엇으로 재나, 사람 손이 필요한 일, 레퍼런스, 무료 한도 |
| 1 PRD | 개요·문제·사용자 시나리오·성공 지표·범위 |
| 2 기능 트리 | 번호 붙인 계층 + mindmap, 필수 기반 기능(로그인·탈퇴 등)은 따로 물음 |
| 3 기능 상세 | 권한·규칙·데이터·화면·예외·확인 방법 |
| 4 데이터 모델 | 엔티티·관계·제약 + erDiagram, 행 단위 권한 |
| 5 자체 점검 | 탈퇴·삭제 처리, 알림, 시간대, 동시 수정, 개인정보 |
| 6 확정 | `docs/specs/`에 기능명세서 — 세부 기능마다 요구사항 ID(`R-1`…) |
| 7 plan | `docs/plans/`에 구현 순서 — 단계가 요구사항 ID를 인용, 문서 검사 통과 |

- **같이 하기(기본)**: 단계마다 멈추고 확인. 애매한 정책은 객관식(선택지 3~4개, "(추천)", 한 번에 최대 4개).
- **맡기기**: "나 없이 진행해" — 질문을 처음에 모아 한 번에, 답이 없으면 추천안을 "가정"으로 적고 끝까지. 마지막에 가정을 한 번에 확인.
- **지식베이스 먼저**: 묻기 전에 ADR·지난 명세서의 결정 사항을 찾아, 이미 정한 건 다시 묻지 않습니다. 프로젝트를 할수록 질문이 줄어듭니다.

## /디자인 — design

**사용자 흐름 확인 → 도구 고르기 → 시안 3개 → 사용자 선택 → 세부 → 적용 → 검수 → 보고** 순서로 진행합니다.
사용자가 선택하기 전에는 실제 앱 코드를 바꾸지 않고, 밝은·어두운 화면의 전/후 목업과 움직임·난이도·위험을 한 화면에서 비교합니다. 범위를 줄이라는 지시가 있으면 따르고 생략한 단계를 보고합니다.

- 하나의 `design` 스킬에 도구 선택·문구·UX 검수·보고를 모았습니다. 14개 도구 설명은 `skills/design/references/`에서 필요한 것만 읽습니다.
- 작업할 기기의 실제 설치 상태를 확인합니다. 필요한 도구는 사용자 승인과 무료 여부·설치 내용 확인 후 설치하고 결과를 보고합니다.
- 설계 제안, 구현 확인, 실제 사용자 테스트 결과를 구분합니다. 사용자 테스트를 하지 않았으면 검증 필요로 남깁니다.

## /지식베이스가 까는 것

| 위치 | 내용 |
|---|---|
| `CLAUDE.md` | 늘 지킬 규칙만(200줄 이하): 작업 시작 전, 핵심 규칙, 기록 위치, 워크트리 흐름, Git 컨벤션, AI 도구 |
| `knowledge-base/` | 목차, log(append-only 작업 기록), now(인계 메모), decisions(기본 원칙 ADR 16개), troubleshooting·concepts·runbooks |
| `docs/templates/` | spec·plan·ADR·인터뷰·트러블슈팅·리허설 양식 |
| `.claude/rules/` | 문서 규칙, 상황 → 스킬 표(경로별로 자동으로 읽힘) |
| `scripts/` | 문서·기록·컨텍스트·커밋 메시지 검사와 테스트, 워크트리 정리 |
| `.githooks/`, `.github/workflows/rules.yml` | 커밋 메시지 훅(설치 때 켬), PR 검사(가벼운 것만 — 빌드·테스트는 레포가 더함) |

기본 원칙 ADR: 기록 위치, 비용 0원, 샘플로 먼저 검증, 문서 버전, MCP는 쓰는 것만, 코드 스타일, 코드가 기준, 커밋·문서·기록 검사, 운영 정보 기본 꺼짐, 관리자 조치 확인, 경로별 규칙, 요구사항 ID, now.md 인계, 자율 모드. 팀에 맞지 않는 원칙은 지우지 말고 새 ADR로 뒤집습니다.

- 이미 있는 파일은 덮어쓰지 않고 옆에 `*.intaeng.*`로 만듭니다.
- 먼저 미리보기(무엇이 생기나)를 보여 주고, 승인 뒤 깝니다.

## 언어별 추가 — 러스트
러스트 프로젝트(`Cargo.toml`)가 있는 레포에서 "러스트 규칙 더해줘"라고 하거나 직접:
```
python <플러그인>/scripts/install.py . --add rust
```
| 깔리는 것 | 내용 |
|---|---|
| `.claude/rules/rust.md` | 러스트 파일을 열 때 자동으로 읽히는 규칙: 커밋 전 검사, 테스트 먼저, `unwrap` 금지, 다른 서버와 같이 쓰면 러스트는 `127.0.0.1`의 계산 작업자만 |
| `scripts/check_rust.sh` | cargo 프로젝트마다 `cargo fmt --check`·`clippy -D warnings`·`cargo test` |
| `.github/workflows/rust.yml` | 러스트 파일이 바뀐 PR에서만 위 검사 |
| CLAUDE.md·`.gitignore` | "경로별 규칙"에 한 줄, `target/` 한 줄(이미 있으면 그대로) |

- `Cargo.toml`이 없으면 멈춥니다(`cargo init` 먼저) — 규칙 파일이 가리킬 러스트 파일이 없으면 컨텍스트 검사가 실패해서입니다.
- 다른 언어는 쓰게 되면 같은 방식(`addons/<언어>/`)으로 더합니다.

## Codex에서 쓰기
| | Claude Code | Codex |
|---|---|---|
| 매니페스트 | `.claude-plugin/plugin.json` | `plugin.json`(Agent Plugins 형식) — 이름·버전은 테스트가 맞춤 |
| 마켓플레이스 | 레포 `.claude-plugin/marketplace.json` | 레포 `.agents/plugins/marketplace.json` |
| 설치 | `/plugin install intaeng@taeng-marketplace` | `codex plugin marketplace add taehyeooo/taeng-marketplace` → `/plugins` |
| 부르기 | `/intaeng:기획` 등 한글 명령, 또는 말 | `@intaeng`, 또는 말("기획하자") — 한글 명령(`commands/`)은 Codex에 없음 |
| 깐 레포가 읽는 규칙 | `CLAUDE.md`, `.claude/rules/`(경로별 자동) | `AGENTS.md` → `CLAUDE.md`, `.claude/rules/`는 에이전트가 직접 엶 |

- 스킬 글은 도구 중립으로 씁니다("Claude가" 대신 "에이전트가", 명령 옆에 스킬 이름). 테스트가 막습니다.
- 플러그인 폴더 경로는 `${CLAUDE_PLUGIN_ROOT}`로 쓰고, 바꿔 주지 않는 도구를 위해 대안(`PLUGIN_ROOT`, SKILL.md 위치 기준)을 같이 적습니다.

### 디자인 스킬 인식과 갱신

Claude Code는 `.claude-plugin/plugin.json`의 플러그인에서 `skills/design/SKILL.md`를 찾고, `commands/디자인.md`가 `intaeng:design`을 부릅니다. Codex는 `.agents/plugins/marketplace.json`의 `./plugins/intaeng` → `plugin.json`과 같은 `skills/design/SKILL.md`를 사용합니다. Codex에서는 `@intaeng`과 "디자인하자"로 요청합니다. 두 매니페스트 버전은 0.7.0입니다.

병합 후 설치한 기기마다 갱신합니다.

- Claude Code: `/plugin marketplace update taeng-marketplace` 후 터미널에서 `claude plugin update intaeng@taeng-marketplace`, 새 세션 시작.
- Codex: `codex plugin marketplace upgrade taeng-marketplace` 후 `/plugins`에서 intaeng 갱신 상태 확인, 새 세션 시작.
- 이미 깔린 프로젝트의 `AGENTS.md`와 `.claude/rules/skills.md`는 프로젝트 소유입니다. 디자인 항목을 `design`으로 맞추되 파일 전체를 덮어쓰지 않습니다.
- [변경 기록](CHANGELOG.md)에 통합 범위·플러그인 버전과 기준 문서 날짜(2026-11-20)를 기록했습니다.

## 넣지 않는 것
이 플러그인은 공개 레포에 있습니다. 일하는 **방법**만 담고, 만든 사람의 결정 기록·작업 기록·조사·다른 프로젝트는 담지 않습니다. 테스트(`tests/test_intaeng.py`)가 그런 내용이 섞이면 실패합니다.

## 테스트
```
python plugins/intaeng/tests/test_intaeng.py
```
빈 git 레포에 깔고 문서·컨텍스트 검사와 깐 스크립트의 테스트가 통과하는지, 커밋 훅이 서명을 막는지, 미리보기·덮어쓰지 않기, 누출 검사를 봅니다.

설계: [docs/specs/2026-10-28-intaeng-plugin.md](../../docs/specs/2026-10-28-intaeng-plugin.md)
