# devflow

1인 개발에서 **매일 반복하던 작업**을 Claude Code 플러그인으로 묶었습니다.
여행 영상 → 일정 앱 [Trova](https://github.com/Trovapp/trova-backend)를 만들며 손으로 수십 번 반복한 절차를 그대로 옮겼습니다.

| 구성 | 종류 | 하는 일 |
|---|---|---|
| `commit-guard` | 훅(PreToolUse) | Claude가 `git commit` 하기 직전에 메시지 형식·AI 서명 금지·커밋하면 안 되는 문자열(임시 QA 토큰 등)을 확인하고 어기면 막음 |
| `deploy` | 스킬 + 스크립트 | 빌드 → 진행 중 작업 확인 → 전송·해시 비교 → 백업 → 교체·재시작 → UP 대기 → 배포 후 보안 확인 → 기록 |
| `ship` | 스킬 + 스크립트 | 이슈 → 규칙대로 브랜치·worktree → 빌드·테스트 → `Closes #번호` PR → 머지 → 이슈 닫힘 확인·worktree 정리·후속 명령 |
| `ops-check` | 스킬 + 스크립트 | 운영 상태(서비스·오류 로그·디스크·메모리·응답 시간·멈춘/실패 작업·외부 API 사용량)를 기준과 비교, 배포 후 `--watch` |
| `local-server` | 스킬 + 스크립트 | 기준 커밋으로 맞추기 → 서버 끄기 → 빌드 → .env 불러와 실행 → health UP 대기 |
| `work-record` | 스킬 + 스크립트 | 브랜치의 사실(커밋·테스트 수·최근 배포/QA 시간)을 모아 범위 → 방법 비교 → 확인 틀로 작업 기록 초안 |
| `report` | 스크립트 | 배포·QA 기록 요약 — 횟수, 걸린 시간(중앙값·평균), 단계별 평균 |

## 어떤 서비스에서도
스크립트에는 특정 서비스 내용이 없고, 서비스마다 다른 것은 `~/.config/devflow/<레포>.json` 설정으로 받습니다.
- 배포: 빌드 명령·산출물·서버·헬스 주소·사전 확인·배포 후 확인은 모두 설정. 서버에서 하는 교체·재시작·되돌리기도 `swapCmd`/`restartCmd`/`rollbackCmd`로 바꿀 수 있음(기본: 단일 파일 + systemd)
- 로컬 서버: 빌드·실행 명령(`startCmd`, 기본 `java -jar {jar}`)·포트·헬스 주소를 설정
- 커밋 검사: 메시지 형식 정규식·금지 문자열을 설정
- QA는 [qaflow](https://github.com/taehyeooo/qaflow), 디자인 QA는 [uiflow](https://github.com/taehyeooo/uiflow)로 나뉘어 있습니다(0.3.0에서 qa-sim을 qaflow로 옮김)

## 리포트
작업이 끝나면 HTML 리포트를 남깁니다: `~/.config/flow-reports/<플러그인>/<시각>-<종류>.html`.
다섯 flow 플러그인(startflow·devflow·qaflow·uiflow·benchflow)의 리포트가 한 목록 `~/.config/flow-reports/index.html`에 모입니다(최신이 위, 정상/확인 필요/실패 표시).

## 설치
```
/plugin marketplace add taehyeooo/devflow
/plugin install devflow@devflow
```

## 설정
서버 주소·키 경로·DB 조회 명령은 **공개 레포에 올리지 않도록 레포 밖**에 둡니다.
`~/.config/devflow/<origin 레포 이름>.json` (worktree에서도 같은 파일을 찾음). 예시: [`examples/config.example.json`](examples/config.example.json)

## 사용 기록
`~/.config/devflow/usage.log`, 배포는 `deploy.log`에 시간·결과가 남습니다. 실제 사용 기록은 [docs/usage-trova.md](docs/usage-trova.md).
