# {{name}} — AI 에이전트 안내

이 레포의 규칙은 **[CLAUDE.md](CLAUDE.md)** 에 있다. Claude Code가 아닌 에이전트(Codex 등)도 일을 시작하기 전에 그 파일을 끝까지 읽고 그대로 따른다 — 같은 규칙을 두 곳에 쓰지 않으려고 이 파일은 안내만 둔다.

- **경로별 규칙**: Claude Code는 `.claude/rules/*.md`를 그 경로를 열 때 자동으로 읽는다. 다른 에이전트는 파일을 고치기 전에 `.claude/rules/`에서 frontmatter `paths`가 그 파일에 맞는 규칙을 직접 열어 읽는다.
- **새 세션**: [knowledge-base/now.md](knowledge-base/now.md)(인계 메모)부터 읽는다.
- **intaeng 플러그인 스킬**: Claude Code의 `/intaeng:기획` 같은 한글 명령은 다른 도구에는 없다. 같은 스킬을 이름이나 말로 부른다.

| Claude Code 명령 | 스킬 | 말로 부르기 |
|---|---|---|
| `/intaeng:지식베이스` | `knowledge-base` | "지식베이스 깔아줘", "러스트 규칙 더해줘" |
| `/intaeng:기획` | `feature-spec` | "기획하자", "기능명세서 뽑아줘" |
| `/intaeng:디자인` | `design-flow` | "디자인하자", "화면 시안 보여줘" |
| `/intaeng:시작` | `start-task` | "새 작업 시작해줘" |
| `/intaeng:이어하기` | `resume` | "어디까지 했지" |
| `/intaeng:마무리` | `wrap-up` | "마무리해줘", "PR 올려줘" |
| `/intaeng:머지` | `merge-train` | "PR 다 머지해줘" |
| `/intaeng:맡기기` | `delegate-pr` | "이 단계는 에이전트한테 맡겨" |
| `/intaeng:스펙점검` | `spec-check` | "요구사항 다 구현됐어?" |

- **커밋**: `타입: 내용`만. 어떤 도구든 AI 서명·`Co-Authored-By`·이모지를 붙이지 않는다(훅이 막는다). `--no-verify` 금지.
