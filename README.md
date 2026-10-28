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
/plugin install evalflow@taeng-marketplace
/plugin install reviewflow@taeng-marketplace
/plugin install intaeng@taeng-marketplace
```

필요한 것만 골라 설치해도 됩니다. 업데이트는 `/plugin marketplace update taeng-marketplace`.

### intaeng으로 새 레포 시작하기

"내가 없어도 개발이 돌아가는 레포"를 만드는 뼈대입니다. Claude Code에서:

1. **마켓플레이스 등록**(PC마다 한 번): `/plugin marketplace add taehyeooo/taeng-marketplace`
2. **설치**: `/plugin install intaeng@taeng-marketplace` → 명령이 안 보이면 Claude Code를 다시 시작
3. **새 레포 폴더에서 Claude Code를 켜고** `/intaeng:지식베이스` (`/지식베이스`까지 치면 목록에서 고를 수 있습니다)
   - 프로젝트 이름과 한 줄 소개를 묻습니다.
   - 무엇이 생기는지 미리보기를 보여 주고, 승인하면 깝니다: 규칙만 담은 `CLAUDE.md`, `knowledge-base/`(목차·작업 기록·인계 메모·기본 원칙 ADR 16개), `docs/templates/` 양식, 검사 스크립트·커밋 메시지 훅·PR 검사(GitHub Actions).
   - 이미 있는 파일은 덮어쓰지 않고 옆에 `*.intaeng.*`로 만듭니다.
4. **첫 커밋**: `chore: 지식베이스 뼈대` — 이제부터 커밋 메시지 규칙(`타입: 내용`, AI 서명 금지)을 훅이 검사합니다.
5. **그다음**: `knowledge-base/now.md`의 "다음 할 일"부터. 기획은 `/intaeng:기획`(아이디어 → 기능명세서 → 구현 순서), 화면은 `/intaeng:디자인`.

- 업데이트: `/plugin marketplace update taeng-marketplace` → 스킬·명령이 새 버전으로 바뀝니다. 이미 깐 파일(CLAUDE.md 등)은 그 레포 것이라 바뀌지 않습니다.
- 지우기: `/plugin uninstall intaeng@taeng-marketplace` (깐 파일은 그대로 남습니다).
- 자세히: [plugins/intaeng](plugins/intaeng/README.md)

#### /기획은 이렇게 돌아갑니다
아이디어 한 줄 → **PRD**(문제·사용자·범위) → **기능 트리**(로그인·탈퇴 같은 기반 기능도 챙김) → **기능 상세**(권한·규칙·데이터·예외) → **데이터 모델** → **자체 점검** → **기능명세서**(`docs/specs/`) → **구현 순서**(`docs/plans/`).
- 애매한 정책은 AI가 정하지 않고 객관식으로 묻습니다. 이미 정한 건 지식베이스에서 찾아 다시 묻지 않습니다.
- 평소엔 단계마다 확인받고, "나 없이 진행해"라고 하면 추천안을 가정으로 적고 끝까지 갑니다.

#### /디자인은 이렇게 돌아갑니다
**구조 시안 3개**(배치·흐름이 다른 것) → 하나 고르기 → **세부 시안**(글꼴·색 느낌, 움직임·빈 상태 같은 디테일) → 조합 고르기 → **적용** → 써 보고 의견 → **고도화**(의견마다 디자인 규칙에 맞춰 고치고 전·후 비교).
- 시안은 그림이 아니라 실제 앱 안 변형이라, 고른 시안이 곧 실제 앱입니다. 시안들은 나란히 보기 페이지에서 같은 폭으로 띄워 직접 눌러 봅니다.
- 큰 것(구조)부터 고르고 작은 것(글꼴·색)은 나중에 고릅니다.

## 플러그인

| 플러그인 | 하는 일 | 언제 쓰나 |
|---|---|---|
| [startflow](plugins/startflow) | 나만의 기본 지침(CLAUDE.md)·시크릿 무시 규칙·기록 문서·다른 플러그인 설정 뼈대를 한 번에 세팅 | 새 서비스를 시작할 때 |
| [devflow](plugins/devflow) | 배포·운영 확인·커밋 규칙 검사·작업 기록, 배포·QA 시간 기록 | 매일 개발·배포할 때 |
| [qaflow](plugins/qaflow) | QA 환경 준비/원복, 시나리오 재생, 테스트 데이터 자동 정리, API 스모크, 페르소나 QA | 기능을 고친 뒤·배포 전 |
| [uiflow](plugins/uiflow) | 글자 크기·기기별 화면 훑기, 고친 뒤 자동 검사, 전·후 비교 이미지 | 화면을 고칠 때 |
| [benchflow](plugins/benchflow) | 같은 측정을 N번 돌려 레포에 남기고, 기준값 대비 좋아짐/나빠짐 판정·알림, 코드를 읽고 개선 추천 | 성능·비용 결정을 할 때, QA·PR 때 자동 |
| [evalflow](plugins/evalflow) | AI 출력 정확도를 promptfoo로 정답 대비 채점·기록, 새로 틀린 케이스 알림, 프롬프트·코드를 읽고 추천 | 프롬프트·모델·후처리를 바꿀 때 |
| [reviewflow](plugins/reviewflow) | 정확성·테스트·보안·프로젝트 규칙(ADR) 네 관점 동시 리뷰 + 검증 | PR을 만들기 전·머지 전 |
| [intaeng](plugins/intaeng) | `/intaeng:지식베이스` — 내가 없어도 개발이 돌아가게 일하는 방식의 뼈대(규칙·지식베이스 구조·기본 원칙 ADR·양식·검사·훅·CI)를 깐다. `/intaeng:기획` — 기능명세서·구현 순서. `/intaeng:디자인` — 디자인 4단계 | 새 레포를 시작할 때 |

## 공통 원칙

- **어떤 서비스에도 쓴다**: 스크립트에는 서비스 내용이 없고, 서비스마다 설정 파일만 다르다.
- **설정은 레포 밖에**: `~/.config/<플러그인>/<레포 이름>.json` — 시크릿·서비스 정보가 이 레포나 작업 레포에 섞이지 않는다.
- **추천은 근거로**: 개선 추천은 실제로 읽은 코드(`경로:줄`)·근거 수치·예상 효과(추정 표시)·검증 방법이 있어야 내고, 적용은 사용자가 고른 것만.
- **끝나면 리포트**: 모든 플러그인이 작업 끝에 HTML 리포트를 남기고, `~/.config/flow-reports/index.html`에서 한 번에 본다.

## 기록

각 플러그인은 원래 따로 있던 레포(taehyeooo/devflow 등)에서 커밋 기록째 옮겨 왔습니다.
