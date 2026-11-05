---
name: knowledge-base
description: 새 레포에 "내가 없어도 개발이 돌아가는" 일하는 방식의 뼈대를 깐다 — 규칙만 담은 CLAUDE.md, knowledge-base/(목차·결정 목록·log·now·트러블슈팅·개념·대응 문서), 기본 원칙 ADR 16개, docs/templates 양식 6개, 문서·기록·컨텍스트 검사 스크립트, 커밋 메시지 훅, GitHub Actions. "지식베이스 깔아줘", "처음 세팅", "이 레포에 규칙 넣어줘"에 쓴다.
---

# 지식베이스 깔기 (intaeng)

## 순서
1. 레포 루트인지 확인한다(`git rev-parse --show-toplevel`). git 레포가 아니면 `git init`을 할지 묻는다.
2. 두 가지만 묻는다(한 번에): 프로젝트 이름(기본: 폴더 이름), 한 줄 소개(누가, 무엇을 하면, 무엇을 얻나).
3. 미리보기: `python "${CLAUDE_PLUGIN_ROOT}/scripts/install.py" . --name "<이름>" --intro "<소개>" --dry-run` — 새로 생길 파일과 "옆에(이미 있음)"로 만들 파일을 보여 준다.
   - `${CLAUDE_PLUGIN_ROOT}`는 이 플러그인 폴더다. 글자 그대로 남아 있으면(바꿔 주지 않는 도구) 환경 변수 `PLUGIN_ROOT`·`CLAUDE_PLUGIN_ROOT`를, 그것도 없으면 이 SKILL.md에서 두 단계 위 폴더(`skills/<스킬>/` 의 위의 위)를 쓴다.
4. 사용자가 좋다고 하면 `--dry-run` 없이 실행한다. 커밋 메시지 훅(`core.hooksPath .githooks`)도 이때 켠다 — 원하지 않으면 `--no-hooks`.
5. 확인: `python scripts/check_docs.py`, `python scripts/check_context.py`가 통과하는지 본다.
6. `*.intaeng.*`로 옆에 만든 파일이 있으면 원래 파일과 무엇이 다른지 보여 주고, 합칠지 사용자와 정한다(덮어쓰지 않는다).
7. 결과 보고: 깐 것, 다음 할 일(첫 기능 spec — `docs/templates/spec.md`, now.md "다음 할 일"). 첫 커밋은 사용자 확인 뒤 `chore: 지식베이스 뼈대`(트레일러·AI 서명 없이).

## 언어별 추가 (러스트)
레포에 러스트 프로젝트가 있으면(`Cargo.toml` — 없으면 `cargo init` 먼저) 규칙·검사·CI를 더한다. 뼈대를 깐 뒤 언제든, 두 번 해도 된다.
1. 미리보기: `python "${CLAUDE_PLUGIN_ROOT}/scripts/install.py" . --add rust --dry-run`
2. 좋다고 하면 `--dry-run` 없이. 깔리는 것: `.claude/rules/rust.md`(커밋 전 검사·테스트 먼저·`unwrap` 금지·다른 서버와 쓸 때 `127.0.0.1`만), `scripts/check_rust.sh`(fmt·clippy·test), `.github/workflows/rust.yml`(러스트 파일이 바뀐 PR에서만), CLAUDE.md "경로별 규칙"에 한 줄, `.gitignore`에 `target/`.
3. 확인: `python scripts/check_context.py`, 러스트 도구가 있으면 `sh scripts/check_rust.sh`. 이 PC에 러스트 도구(rustup)가 없으면 설치는 사람 단계로 알린다.

## 깔리는 것
- `CLAUDE.md` — 늘 지킬 규칙만(작업 시작 전, 핵심 규칙, 기록 위치, 워크트리 흐름, Git 컨벤션, AI 도구)
- `knowledge-base/` — index, log(append-only), now(인계 메모), decisions(기본 원칙 ADR 16개와 목록), troubleshooting·concepts·runbooks README
- `docs/templates/` — spec·plan·ADR·인터뷰·트러블슈팅·리허설, `docs/specs`·`docs/plans` 자리
- `.claude/rules/` — 문서 규칙, 상황 → 스킬 표
- `scripts/` — 검사 스크립트(문서·기록·컨텍스트·커밋 메시지)와 테스트, 워크트리 정리
- `.githooks/commit-msg`, `.github/workflows/rules.yml`(가벼운 검사만 — 빌드·테스트 잡은 그 레포가 더한다)

## 하지 않는 것
- 이미 있는 파일을 덮어쓰지 않는다.
- 다른 레포의 지식(결정·기록·조사) 내용은 깔지 않는다 — 깔리는 ADR은 처음 보는 팀에도 맞는 기본 원칙뿐이다. 맞지 않는 원칙은 지우지 말고 새 ADR로 뒤집는다.
