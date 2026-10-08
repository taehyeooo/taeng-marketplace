---
name: local-server
description: 로컬 백엔드 서버를 기준 커밋으로 다시 띄운다 — 포트의 서버 끄기, 빌드(실행 중 JAR을 덮어쓰지 않게 끈 뒤), .env 불러와 실행, health UP 대기, 걸린 시간 기록. "로컬 서버 재시작", 배포·QA 전후, 기능 브랜치 JAR로 QA할 때 쓴다.
---

# 로컬 서버 (devflow)

스크립트: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/local-server.sh" <명령>`

- `status` — 지금 커밋과 health
- `restart --ref origin/main` — 머지 후 기준 커밋으로 맞추고 빌드·재시작(커밋하지 않은 변경이 있으면 멈춤)
- `restart --jar <경로>` — 기능 브랜치에서 만든 JAR로 QA할 때(빌드 생략). QA가 끝나면 `restart --ref origin/main`으로 되돌린다.
- `stop`

배포 스크립트가 같은 폴더의 JAR을 다시 빌드하면 실행 중인 서버가 깨질 수 있으니, 배포 전에 `stop`, 배포 후 `restart --jar <배포한 JAR>` 순서로 한다.
설정: `~/.config/devflow/<레포>.json`의 `local` (dir, port, envFile, build, artifact, logFile).
