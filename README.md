# taeng-marketplace

1인 개발에서 매일 반복하던 일을 자동화한 Claude Code 플러그인 모음입니다.
반복 작업은 플러그인에 맡기고, 아낀 시간은 제품과 다른 역량에 씁니다.

## 설치

```
/plugin marketplace add taehyeooo/taeng-marketplace
/plugin install startflow@taeng-marketplace
/plugin install devflow@taeng-marketplace
/plugin install qaflow@taeng-marketplace
/plugin install uiflow@taeng-marketplace
/plugin install benchflow@taeng-marketplace
```

필요한 것만 골라 설치해도 됩니다. 업데이트는 `/plugin marketplace update taeng-marketplace`.

## 플러그인

| 플러그인 | 하는 일 | 언제 쓰나 |
|---|---|---|
| [startflow](plugins/startflow) | 나만의 기본 지침(CLAUDE.md)·시크릿 무시 규칙·기록 문서·다른 플러그인 설정 뼈대를 한 번에 세팅 | 새 서비스를 시작할 때 |
| [devflow](plugins/devflow) | 배포·운영 확인·커밋 규칙 검사·작업 기록, 배포·QA 시간 기록 | 매일 개발·배포할 때 |
| [qaflow](plugins/qaflow) | QA 환경 준비/원복, 시나리오 재생, 테스트 데이터 자동 정리, API 스모크, 페르소나 QA | 기능을 고친 뒤·배포 전 |
| [uiflow](plugins/uiflow) | 글자 크기·기기별 화면 훑기, 고친 뒤 자동 검사, 전·후 비교 이미지 | 화면을 고칠 때 |
| [benchflow](plugins/benchflow) | 같은 측정을 N번 돌려 중앙값·p90을 실행 환경·커밋과 함께 파일로 남기고 전·후 비교 | 성능·비용 결정을 할 때 |

## 공통 원칙

- **어떤 서비스에도 쓴다**: 스크립트에는 서비스 내용이 없고, 서비스마다 설정 파일만 다르다.
- **설정은 레포 밖에**: `~/.config/<플러그인>/<레포 이름>.json` — 시크릿·서비스 정보가 이 레포나 작업 레포에 섞이지 않는다.
- **끝나면 리포트**: 모든 플러그인이 작업 끝에 HTML 리포트를 남기고, `~/.config/flow-reports/index.html`에서 한 번에 본다.

## 기록

각 플러그인은 원래 따로 있던 레포(taehyeooo/devflow 등)에서 커밋 기록째 옮겨 왔습니다.
